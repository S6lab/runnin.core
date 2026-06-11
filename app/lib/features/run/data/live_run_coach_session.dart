import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/coach_live/data/coach_context_manager.dart';
import 'package:runnin/features/coach_live/data/coach_live_beacon_remote_datasource.dart';
import 'package:runnin/features/location_weather/data/location_weather_controller.dart';
import 'package:runnin/features/coach_live/data/live_audio_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Sessão de coach ao vivo via **s6-ai** (microsserviço de IA).
///
/// Arquitetura (substitui a conexão direta app→Google via token efêmero):
///  - runnin-api cria a sessão no s6-ai (`POST /coach/live-session`) montando
///    o contexto (perfil, roteiro, clima, prefs) e devolve {sessionId, wsUrl}.
///  - App conecta no WS do s6-ai. O s6-ai é o DONO do socket Gemini:
///    systemInstruction, CueQueue anti-sobreposição (P0–P3, dedup por km),
///    gate de preamble, rotação e reconexão com o Google são server-side.
///  - App envia eventos como frames JSON {type:'event', event, data} e
///    recebe áudio PCM 24kHz em frames binários + estados/cue_text em JSON.
///  - Push-to-talk foi REMOVIDO (decisão de produto — TF s6-ai).
///
/// Fallback HTTP: com o WS caído, eventos vão pra
/// `POST {s6}/v1/live/sessions/:id/events` que devolve {text, audioB64}.
class LiveRunCoachSession {
  LiveRunCoachSession({
    CoachLiveBeaconRemoteDatasource? beacon,
    Dio? dio,
    LiveAudioService? audio,
  })  : _beaconRemote = beacon ?? CoachLiveBeaconRemoteDatasource(),
        _dio = dio ?? apiClient,
        _audio = audio ?? LiveAudioService();

  final CoachLiveBeaconRemoteDatasource _beaconRemote;
  final Dio _dio;
  final LiveAudioService _audio;

  // Reconexão exponencial ao s6-ai (o s6-ai cuida da reconexão ao Google).
  static const List<Duration> _reconnectBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];
  static const int _maxReconnectAttempts = 10;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _transcriptsCtrl = StreamController<String>.broadcast();
  final BytesBuilder _webPcm = BytesBuilder();

  bool _open = false;
  bool _disposed = false;
  bool _intentionalClose = false;

  String? _sessionId;
  String? _wsUrl;
  String? _runId;
  String? _currentTrigger;
  int _generation = 0;

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// Eventos enfileirados enquanto o WS está caído (dedup por evento, cap 3).
  /// A serialização anti-sobreposição REAL é a CueQueue do s6-ai — isso aqui
  /// só preserva o último snapshot de cada evento até a reconexão.
  final List<MapEntry<String, Map<String, dynamic>>> _pendingEvents = [];

  /// Cada item é o transcript de UMA fala completa do coach.
  Stream<String> get transcripts => _transcriptsCtrl.stream;
  bool get isOpen => _open;
  bool get hasPendingReconnect => _reconnectTimer != null;
  int get generation => _generation;

  /// O bloc registra um getter de métricas correntes — carimba o beacon
  /// de histórico quando uma fala fecha.
  RunMetricsSnapshot Function()? _metricsProvider;
  // ignore: use_setters_to_change_properties
  void setMetricsProvider(RunMetricsSnapshot Function() provider) {
    _metricsProvider = provider;
  }

  /// Abre a sessão: cria no runnin-api (que chama o s6-ai) e conecta o WS.
  /// Retorna false se não conseguiu (corrida segue sem voz).
  Future<bool> open({String? planSessionId, String? runId}) async {
    if (_open) return true;
    _runId = runId;
    _intentionalClose = false;

    final created = await _createSession(planSessionId);
    if (!created) return false;
    final ok = await _connect();
    if (ok) _reconnectAttempt = 0;
    return ok;
  }

  Future<bool> _createSession(String? planSessionId) async {
    try {
      final weather = locationWeatherController.weather;
      final body = <String, dynamic>{
        'planSessionId': ?planSessionId,
        if (weather != null) ...{
          'temperatureC': weather.temperatureC,
          'humidityPercent': weather.humidityPercent,
          'windKmh': weather.windKmh,
        },
      };
      final res = await _dio.post<Map<String, dynamic>>(
        '/coach/live-session',
        data: body.isEmpty ? null : body,
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final sessionId = res.data?['sessionId'] as String?;
      final wsUrl = res.data?['wsUrl'] as String?;
      if (sessionId == null || wsUrl == null) return false;
      _sessionId = sessionId;
      _wsUrl = wsUrl;
      Logger.info('run.coach.s6.session_created', context: {
        'sessionId': sessionId,
        'planSession': planSessionId != null,
      });
      return true;
    } catch (e) {
      Logger.warn('run.coach.s6.session_create_failed', context: {'err': '$e'});
      return false;
    }
  }

  Future<bool> _connect() async {
    final sessionId = _sessionId;
    final wsUrl = _wsUrl;
    if (sessionId == null || wsUrl == null) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final uri = Uri.parse(wsUrl).replace(queryParameters: {
        'sessionId': sessionId,
        'token': token ?? '',
      });
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _open = true;
      _sub = channel.stream.listen(
        _onFrame,
        onError: (Object err) {
          Logger.warn('run.coach.s6.ws_error', context: {'err': '$err'});
          unawaited(_beacon('ws_error', error: err.toString()));
          _open = false;
          _maybeScheduleReconnect(err: err);
        },
        onDone: () {
          _open = false;
          unawaited(_beacon('ws_close'));
          _maybeScheduleReconnect();
        },
      );
      Logger.info('run.coach.s6.open_ok', context: {
        'sessionId': sessionId,
        'generation': _generation,
      });
      unawaited(_beacon('open_ok'));
      _drainPendingEvents();
      return true;
    } catch (e) {
      Logger.warn('run.coach.s6.open_failed', context: {'err': '$e'});
      unawaited(_beacon('open_failed', error: e.toString()));
      return false;
    }
  }

  void _onFrame(dynamic raw) {
    // Frame binário = PCM 24kHz da fala do coach.
    if (raw is List<int>) {
      final pcm = raw is Uint8List ? raw : Uint8List.fromList(raw);
      if (kIsWeb) {
        _webPcm.add(pcm);
      } else {
        _audio.addSpeakerChunk(pcm);
      }
      return;
    }
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'state':
          _onState(msg);
        case 'cue_text':
          _onCueText((msg['text'] as String?) ?? '');
        case 'error':
          Logger.warn('run.coach.s6.server_error', context: {'code': msg['code']});
      }
    } catch (e) {
      Logger.warn('run.coach.s6.frame_parse_failed', context: {'err': '$e'});
    }
  }

  void _onState(Map<String, dynamic> msg) {
    final state = msg['state'] as String?;
    if (msg['generation'] is int) _generation = msg['generation'] as int;
    switch (state) {
      case 'turnComplete':
        if (kIsWeb) {
          final pcm = _webPcm.takeBytes();
          if (pcm.isNotEmpty) {
            final wav = _pcmToWav(pcm, 24000);
            playCoachAudio(base64Encode(wav), mimeType: 'audio/wav');
          }
        } else {
          unawaited(_audio.flushAndPlay());
        }
      case 'interrupted':
        // Preempção server-side (ex: km_reached cortou half_km) — descarta
        // o áudio parcial acumulado; o cue vencedor chega em seguida.
        if (kIsWeb) {
          _webPcm.clear();
        } else {
          _audio.discardSpeakerBuffer();
        }
      case 'gone':
        // s6-ai esgotou a reconexão com o Google. Sessão morta de verdade.
        Logger.warn('run.coach.s6.upstream_gone');
        unawaited(_audio.releaseDucking());
      case 'cue_skipped':
        Logger.info('run.coach.s6.cue_skipped', context: {
          'event': msg['event'],
          'reason': msg['reason'],
        });
    }
  }

  void _onCueText(String text) {
    final spoken = text.trim();
    if (spoken.isEmpty) return;
    final runId = _runId;
    if (runId != null) {
      unawaited(_beaconRemote.logCoachTurn(
        runId: runId,
        text: spoken,
        trigger: _currentTrigger ?? 'unknown',
        sessionGeneration: _generation,
        metrics: _metricsProvider?.call(),
      ));
    }
    if (!_transcriptsCtrl.isClosed) _transcriptsCtrl.add(spoken);
  }

  /// Envia um evento de cue (um dos 8: start, half_km, km_reached,
  /// bpm_alert, pace_alert, goal_reached, finish, no_movement).
  /// WS aberto → frame JSON (o s6-ai serializa via CueQueue).
  /// WS caído → enfileira (dedup, cap 3) + tenta fallback HTTP.
  void sendEvent(String event, Map<String, dynamic> data) {
    _currentTrigger = event;
    if (_open) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'event', 'event': event, 'data': data}));
        return;
      } catch (e) {
        Logger.warn('run.coach.s6.send_failed', context: {'err': '$e'});
        _open = false;
      }
    }
    _pendingEvents.removeWhere((e) => e.key == event);
    _pendingEvents.add(MapEntry(event, data));
    while (_pendingEvents.length > 3) {
      _pendingEvents.removeAt(0);
    }
    unawaited(_sendEventViaHttp(event, data));
    _maybeScheduleReconnect();
  }

  /// Fallback HTTP direto no s6-ai: devolve {text, audioB64} e toca local.
  Future<void> _sendEventViaHttp(String event, Map<String, dynamic> data) async {
    final sessionId = _sessionId;
    final wsUrl = _wsUrl;
    if (sessionId == null || wsUrl == null) return;
    try {
      final httpBase = wsUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://')
          .replaceFirst(RegExp(r'/v1/live$'), '');
      final res = await _dio.post<Map<String, dynamic>>(
        '$httpBase/v1/live/sessions/$sessionId/events',
        data: {'event': event, 'data': data},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      // Entregue: remove da fila de reenvio (senão falaria 2x no reconnect).
      _pendingEvents.removeWhere((e) => e.key == event);
      final text = res.data?['text'] as String?;
      final audio = res.data?['audioB64'] as String?;
      if (audio != null && audio.isNotEmpty) {
        playCoachAudio(audio, mimeType: (res.data?['audioMimeType'] as String?) ?? 'audio/wav');
      }
      if (text != null && text.isNotEmpty) _onCueText(text);
      Logger.info('run.coach.s6.http_fallback_ok', context: {'event': event});
    } on DioException catch (e) {
      // 409 = WS reconectou no meio tempo; 204 = cue dropado (dedup/prefs).
      final status = e.response?.statusCode;
      if (status == 409) _pendingEvents.removeWhere((p) => p.key == event);
      Logger.info('run.coach.s6.http_fallback_skip', context: {
        'event': event,
        'status': status,
      });
    } catch (e) {
      Logger.warn('run.coach.s6.http_fallback_failed', context: {'err': '$e'});
    }
  }

  void _drainPendingEvents() {
    if (_pendingEvents.isEmpty) return;
    final queued = List<MapEntry<String, Map<String, dynamic>>>.from(_pendingEvents);
    _pendingEvents.clear();
    // Sem throttle client-side: a CueQueue do s6-ai serializa e deduplica.
    for (final e in queued) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'event', 'event': e.key, 'data': e.value}));
      } catch (_) {/* ignore */}
    }
  }

  /// Rearma a reconexão depois de uma suspensão longa (tela bloqueada).
  /// O backoff desiste após [_maxReconnectAttempts] (~3min) — se o iOS
  /// segurou o app suspenso por mais que isso, o coach ficava mudo até o
  /// fim da corrida. Chamado pelo RunBloc quando o app volta pro
  /// foreground com run ativa: zera o contador e tenta reconectar já.
  void ensureConnected() {
    if (_disposed || _intentionalClose || _open) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      Logger.info('run.coach.s6.reconnect_rearmed_on_resume', context: {
        'previousAttempts': _reconnectAttempt,
      });
    }
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _maybeScheduleReconnect();
  }

  void _maybeScheduleReconnect({Object? err}) {
    String? skipReason;
    if (_disposed) {
      skipReason = 'disposed';
    } else if (_intentionalClose) {
      skipReason = 'intentional_close';
    } else if (_open) {
      skipReason = 'already_open';
    } else if (_reconnectTimer != null) {
      skipReason = 'already_scheduled';
    } else if (_reconnectAttempt >= _maxReconnectAttempts) {
      skipReason = 'max_attempts_exhausted';
    }
    if (skipReason != null) {
      if (skipReason == 'max_attempts_exhausted') {
        Logger.warn('run.coach.s6.reconnect_exhausted', context: {
          'attempts': _reconnectAttempt,
        });
        unawaited(_audio.releaseDucking());
      }
      return;
    }
    final attempt = _reconnectAttempt;
    final delay = _reconnectBackoff[attempt.clamp(0, _reconnectBackoff.length - 1)];
    _reconnectAttempt = attempt + 1;
    unawaited(_beacon('reconnect_attempt'));
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_disposed || _intentionalClose || _open) return;
      await _cleanupChannel();
      final ok = await _connect();
      if (ok) {
        _reconnectAttempt = 0;
        unawaited(_beacon('reconnect_ok'));
      } else {
        unawaited(_beacon('reconnect_failed'));
        _maybeScheduleReconnect(err: err);
      }
    });
  }

  Future<void> _cleanupChannel() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {/* ignore */}
    _channel = null;
  }

  /// Diagnóstico best-effort (cai no Cloud Logging do runnin-api).
  Future<void> _beacon(String phase, {String? error}) async {
    try {
      await _dio.post<void>('/coach/live-diag', data: {
        'phase': phase,
        'error': ?error,
        'runId': ?_runId,
        'sessionId': ?_sessionId,
        'generation': _generation,
        'attempt': phase == 'reconnect_attempt' ? _reconnectAttempt : null,
        'transport': 's6-ws',
      });
    } catch (_) {/* diagnóstico é best-effort */}
  }

  /// Fecha a sessão DEPOIS que a fala em curso terminar de tocar. Usado no
  /// finish: o timer fixo de 30s cortava o fim do resumo quando a geração
  /// (~5-8s) + fala longa passavam do teto. Espera o playback real
  /// completar (com teto duro de 90s no waitPlaybackEnd) e só então fecha.
  Future<void> closeAfterSpeech() async {
    try {
      await _audio.waitPlaybackEnd();
    } catch (_) {/* best-effort — fecha mesmo assim */}
    await close();
  }

  Future<void> close() async {
    _disposed = true;
    _intentionalClose = true;
    _open = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pendingEvents.clear();
    try {
      _channel?.sink.add(jsonEncode({'type': 'close'}));
    } catch (_) {/* ignore */}
    await _cleanupChannel();
    // Encerra a sessão server-side (libera o socket Gemini do s6-ai).
    final sessionId = _sessionId;
    final wsUrl = _wsUrl;
    if (sessionId != null && wsUrl != null) {
      try {
        final httpBase = wsUrl
            .replaceFirst('wss://', 'https://')
            .replaceFirst('ws://', 'http://')
            .replaceFirst(RegExp(r'/v1/live$'), '');
        await _dio.delete<void>('$httpBase/v1/live/sessions/$sessionId');
      } catch (_) {/* best-effort */}
    }
    await _audio.dispose();
    if (!_transcriptsCtrl.isClosed) await _transcriptsCtrl.close();
  }

  /// PCM 16-bit mono → WAV (RIFF). Usado só no web pra tocar via <audio>.
  Uint8List _pcmToWav(Uint8List pcm, int sampleRate) {
    const channels = 1;
    const bits = 16;
    final byteRate = sampleRate * channels * bits ~/ 8;
    final blockAlign = channels * bits ~/ 8;
    final dataLen = pcm.length;
    final h = ByteData(44);
    void str(int o, String v) {
      for (var i = 0; i < v.length; i++) {
        h.setUint8(o + i, v.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    h.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, sampleRate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bits, Endian.little);
    str(36, 'data');
    h.setUint32(40, dataLen, Endian.little);
    final out = Uint8List(44 + dataLen);
    out.setRange(0, 44, h.buffer.asUint8List());
    out.setRange(44, 44 + dataLen, pcm);
    return out;
  }
}
