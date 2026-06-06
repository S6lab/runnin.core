import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gemini_live/gemini_live.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/coach_live/data/coach_context_manager.dart';
import 'package:runnin/features/coach_live/data/coach_live_beacon_remote_datasource.dart';
import 'package:runnin/features/location_weather/data/location_weather_controller.dart';
import 'package:runnin/features/coach_live/data/live_audio_service.dart';

/// Sessão Gemini Live nativa **efêmera/rotacional** que acompanha a corrida.
///
/// Mudança vs. versão anterior (long-lived):
///  - Contexto vive FORA da sessão, no [CoachContextManager] passado pelo
///    bloc. A sessão é descartável; quem morre é a conexão, não o histórico.
///  - [rotateSession] abre uma nova sessão Live, espera o `setupComplete`,
///    injeta um preamble curto com o snapshot do manager como primeiro
///    `sendText`, e SÓ ENTÃO fecha a velha (swap atômico — sem "buraco"
///    audível pro user). Isso resolve a degradação observada por volta do
///    km 3 (acúmulo de áudio PCM no histórico interno do socket).
///  - Reconexão automática em close não-clean (queda de sinal/wifi) com
///    backoff exponencial 1s → 2s → 4s → 8s → 30s.
///  - `_reopenAndSend` foi substituído por enfileiramento via [_pendingSends]
///    enquanto reconecta — ao reconectar, drena a fila com o preamble.
///
/// Mantém:
///  - 1 sessão ATIVA por vez (modelo native-audio, voz contínua)
///  - `outputAudioTranscription` (texto == voz no banner)
///  - Push-to-talk via [startTalk]/[stopTalk]
class LiveRunCoachSession {
  LiveRunCoachSession({
    required CoachContextManager contextManager,
    CoachLiveBeaconRemoteDatasource? beacon,
    Dio? dio,
    LiveAudioService? audio,
  })  : _ctxMgr = contextManager,
        _beaconRemote = beacon ?? CoachLiveBeaconRemoteDatasource(),
        _dio = dio ?? apiClient,
        _audio = audio ?? LiveAudioService();

  final CoachContextManager _ctxMgr;
  final CoachLiveBeaconRemoteDatasource _beaconRemote;
  final Dio _dio;
  final LiveAudioService _audio;

  static const _voiceDefault = 'Charon';

  // Rotação adaptativa. Threshold de age reduzido pra 6min depois de
  // observar Gemini Live caindo com code 1011 em sessões de exatos
  // ~10min — 6min dá ~4min de folga pra rotação completar antes do cap.
  static const int rotationTurnThreshold = 6;
  static const Duration rotationAgeThreshold = Duration(minutes: 6);
  // Token efêmero dura 30min — refetch quando faltam <5min pra evitar
  // que o token vire pumpkin no meio de uma rotação.
  static const Duration _tokenStaleThreshold = Duration(minutes: 5);

  // Reconexão exponencial.
  static const List<Duration> _reconnectBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  /// Cap de tentativas de reconnect antes de desistir definitivamente.
  /// Sem isso, sessão Gemini fechada por `new_session_expire_time` ficava
  /// tentando reabrir infinito (vimos attempt 28+ nos logs), consumindo
  /// bateria e bandwidth. Após esse cap, a session fica em estado fechado
  /// silente — RunBloc captura `coach.cue.skipped_session_closed` no log.
  static const int _maxReconnectAttempts = 5;

  LiveSession? _session;
  final _transcriptsCtrl = StreamController<String>.broadcast();
  final StringBuffer _turnTranscript = StringBuffer();
  final BytesBuilder _webPcm = BytesBuilder();
  bool _open = false;
  bool _talking = false;
  bool _disposed = false;

  // Snapshot da config do token (rastreio de beacons + reabertura).
  _LiveCoachConfig? _lastConfig;
  DateTime? _tokenExpiresAt;
  String? _runId;
  String? _planSessionId;
  String? _currentTrigger; // alimenta o ctxMgr.recordCoachTurn ao fechar turn
  DateTime _sessionStartedAt = DateTime.now();
  int _turnsThisSession = 0;
  bool _rotating = false;

  // Reconexão.
  bool _intentionalClose = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  final List<String> _pendingSends = <String>[];

  /// Cada item é o transcript de UMA fala completa do coach (texto == voz).
  Stream<String> get transcripts => _transcriptsCtrl.stream;
  bool get isOpen => _open;
  bool get isTalking => _talking;
  bool get hasPendingReconnect => _reconnectTimer != null;
  int get generation => _ctxMgr.generation;
  int get turnsThisSession => _turnsThisSession;
  Duration get sessionAge =>
      _open ? DateTime.now().difference(_sessionStartedAt) : Duration.zero;

  /// Marca o trigger que provocou a próxima fala — alimenta o snapshot do
  /// manager quando o turn fechar. Chamar logo antes de [sendTelemetry].
  // ignore: use_setters_to_change_properties
  void markTrigger(String trigger) {
    _currentTrigger = trigger;
  }

  /// Avalia se vale rotacionar agora. Chamado pelo bloc em transições
  /// naturais (km_reached, segment_start, segment_end). Retorna true se
  /// rotação foi disparada (ou enfileirada por push-to-talk).
  bool shouldRotateNow() {
    if (!_open) return false;
    if (_rotating) return false;
    final byTurns = _turnsThisSession >= rotationTurnThreshold;
    final byAge = sessionAge >= rotationAgeThreshold;
    return byTurns || byAge;
  }

  /// Abre a sessão. Retorna false se não conseguiu (cai pra run sem voz).
  Future<bool> open({String? planSessionId, String? runId}) async {
    if (_open) return true;
    _runId = runId;
    _planSessionId = planSessionId;
    _intentionalClose = false;
    final cfg = await _fetchConfig(planSessionId);
    if (cfg == null) return false;
    _lastConfig = cfg;
    final ok = await _connect(cfg);
    if (ok) {
      _sessionStartedAt = DateTime.now();
      _turnsThisSession = 0;
      _reconnectAttempt = 0;
    }
    return ok;
  }

  /// Rotaciona a sessão: pré-aquece uma nova com o mesmo token (refetch se
  /// stale), injeta preamble do manager como 1º sendText, e SÓ ENTÃO fecha
  /// a velha. Swap atômico — a velha continua respondendo até a nova estar
  /// pronta, evitando "buraco" audível.
  Future<bool> rotateSession({required String reason}) async {
    if (!_open || _rotating || _disposed) return false;
    if (_talking) return false;
    _rotating = true;
    final oldSession = _session;
    try {
      // ignore: avoid_print
      print('run.coach.live.rotate.start reason=$reason turns=$_turnsThisSession ageMs=${sessionAge.inMilliseconds}');
      _LiveCoachConfig cfg;
      if (_isTokenStale()) {
        unawaited(_beacon('token_refresh_required', reason: reason));
        final refreshed = await _fetchConfig(_planSessionId);
        if (refreshed == null) return false;
        _lastConfig = refreshed;
        cfg = refreshed;
      } else {
        cfg = _lastConfig!;
      }

      // Pré-aquece a nova sessão. Durante essa janela, a velha continua
      // respondendo se houver fala em andamento.
      final preamble = _ctxMgr.snapshot().toPromptPreamble();
      final newOk = await _connect(cfg, preamble: preamble, isRotation: true);
      if (!newOk) {
        unawaited(_beacon('rotate_failed', reason: reason));
        return false;
      }

      // Swap completo: fecha a velha SEM disparar reconnect (close intencional).
      try {
        await oldSession?.close();
      } catch (_) {/* ignore */}

      _sessionStartedAt = DateTime.now();
      _turnsThisSession = 0;
      _reconnectAttempt = 0;
      _ctxMgr.bumpGeneration();
      unawaited(_beacon('rotate_ok', reason: reason));
      // ignore: avoid_print
      print('run.coach.live.rotate.ok generation=${_ctxMgr.generation}');
      return true;
    } catch (e) {
      unawaited(_beacon('rotate_failed', reason: reason, error: e.toString()));
      // ignore: avoid_print
      print('run.coach.live.rotate.failed reason=$reason err=$e');
      return false;
    } finally {
      _rotating = false;
    }
  }

  /// Conecta uma sessão Live. Quando [isRotation] for true, [oldSession] é
  /// preservado (caller faz o swap depois). Quando for primeira conexão,
  /// substitui [_session] direto.
  Future<bool> _connect(
    _LiveCoachConfig cfg, {
    String? preamble,
    bool isRotation = false,
  }) async {
    LiveSession? newSession;
    final ready = Completer<bool>();
    try {
      newSession = await LiveService(apiKey: cfg.token, apiVersion: 'v1alpha')
          .connect(
        LiveConnectParameters(
          model: cfg.model,
          config: GenerationConfig(
            responseModalities: [Modality.AUDIO],
            speechConfig: SpeechConfig(
              voiceConfig: VoiceConfig(
                prebuiltVoiceConfig:
                    PrebuiltVoiceConfig(voiceName: cfg.voice),
              ),
            ),
          ),
          systemInstruction: cfg.systemInstruction != null
              ? Content(parts: [Part(text: cfg.systemInstruction!)])
              : null,
          outputAudioTranscription:
              cfg.outputTranscription ? AudioTranscriptionConfig() : null,
          callbacks: LiveCallbacks(
            onMessage: _onMessage,
            onError: (err, _) {
              Logger.error('coach.live.error', err, StackTrace.current, {
                'is_rotation': isRotation,
              });
              unawaited(_beacon('ws_error', error: err.toString()));
              _maybeScheduleReconnect(err: err);
            },
            onClose: (code, reason) {
              final is1008 = code == 1008;
              Logger.warn('coach.live.close', context: {
                'code': code,
                'reason': reason,
                'is1008': is1008,
                'sys_instr_len': cfg.systemInstruction?.length ?? 0,
              });
              _open = false;
              unawaited(_beacon('ws_close', code: code, reason: reason));
              _maybeScheduleReconnect(code: code, reason: reason);
            },
          ),
        ),
      );
      _open = true;
      _session = newSession;
      Logger.info('coach.live.open_ok', context: {
        'model': cfg.model,
        'sys_instr_len': cfg.systemInstruction?.length ?? 0,
        'rotation': isRotation,
      });
      unawaited(_beacon('open_ok'));
      // Injeta preamble imediatamente (rotação OU reconexão pós-queda).
      if (preamble != null && preamble.isNotEmpty) {
        try {
          newSession.sendText(preamble);
        } catch (_) {/* ignore */}
      }
      // Drena fila de sends que ficaram pendentes durante reconexão.
      if (_pendingSends.isNotEmpty) {
        for (final txt in List<String>.from(_pendingSends)) {
          try {
            newSession.sendText(txt);
          } catch (_) {/* ignore */}
        }
        _pendingSends.clear();
      }
      if (!ready.isCompleted) ready.complete(true);
      return true;
    } catch (e) {
      // open_failed costuma ser o 1008 de SETUP (systemInstruction grande na
      // constraint / safety) — o connect() lança antes do setupComplete.
      // ignore: avoid_print
      print('run.coach.live.open_failed: $e rotation=$isRotation');
      unawaited(_beacon('open_failed', error: e.toString()));
      if (!ready.isCompleted) ready.complete(false);
      return false;
    }
  }

  bool _isTokenStale() {
    final exp = _tokenExpiresAt;
    if (exp == null) return true;
    final remaining = exp.difference(DateTime.now());
    return remaining < _tokenStaleThreshold;
  }

  void _maybeScheduleReconnect({int? code, String? reason, Object? err}) {
    // Cada guard emite um beacon `reconnect_skipped` com o motivo —
    // sem isso ficamos cegos quando 1011 não recupera (já caímos uma vez:
    // sessão de 10min do Gemini Live fechou e reconnect não disparou,
    // sem beacon explicando qual guard barrou).
    String? skipReason;
    if (_disposed) {
      skipReason = 'disposed';
    } else if (_intentionalClose) {
      skipReason = 'intentional_close';
    } else if (_rotating) {
      skipReason = 'rotating';
    } else if (_talking) {
      skipReason = 'talking';
    } else if (_runId == null) {
      skipReason = 'no_run_id';
    } else if (code == 1000) {
      skipReason = 'clean_close_1000';
    } else if (_reconnectTimer != null) {
      skipReason = 'already_scheduled';
    } else if (_reconnectAttempt >= _maxReconnectAttempts) {
      skipReason = 'max_attempts_exhausted';
    }
    if (skipReason != null) {
      unawaited(_beacon(
        'reconnect_skipped',
        reason: skipReason,
        code: code,
      ));
      return;
    }

    // Quando o server Google fecha com `new_session_expire_time deadline
    // exceeded`, é o TOKEN que não pode mais abrir sessão nova (NSXT do
    // ephemeral token expirou — limite SDK do Gemini Live, ~10-15min).
    // Marcamos o token como vencido pra forçar refetch no próximo attempt.
    // Sem isso, reusávamos o _lastConfig com token morto e cada open
    // estourava TimeoutException de 10s → loop infinito (28+ attempts
    // observados nos logs).
    if (reason != null && reason.contains('new_session_expire_time')) {
      _tokenExpiresAt = DateTime.now().subtract(const Duration(minutes: 1));
    }
    final isNetwork = err is SocketException ||
        code == 1001 ||
        code == 1006 ||
        code == 1011 ||
        code == 1012 ||
        code == 1013;
    if (!isNetwork && code != null) {
      unawaited(_beacon(
        'reconnect_skipped',
        reason: 'non_recoverable_code',
        code: code,
      ));
      return; // ex: 1008 (constraint) não recupera com retry
    }
    final attempt = _reconnectAttempt;
    final delay = _reconnectBackoff[
        attempt.clamp(0, _reconnectBackoff.length - 1)];
    _reconnectAttempt = attempt + 1;
    unawaited(_beacon(
      'reconnect_attempt',
      reason: reason,
      error: err?.toString(),
    ));
    // ignore: avoid_print
    print('run.coach.live.reconnect.attempt n=$attempt delay=${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_disposed || _intentionalClose || _talking || _open) return;
      final cfg = _isTokenStale()
          ? await _fetchConfig(_planSessionId)
          : _lastConfig;
      if (cfg == null) {
        unawaited(_beacon('reconnect_failed', reason: 'no_config'));
        _maybeScheduleReconnect(code: code, reason: reason, err: err);
        return;
      }
      _lastConfig = cfg;
      final preamble = _ctxMgr.snapshot().toPromptPreamble();
      final ok = await _connect(cfg, preamble: preamble, isRotation: false);
      if (ok) {
        _sessionStartedAt = DateTime.now();
        _turnsThisSession = 0;
        _reconnectAttempt = 0;
        unawaited(_beacon('reconnect_ok'));
        // ignore: avoid_print
        print('run.coach.live.reconnect.ok');
      } else {
        unawaited(_beacon('reconnect_failed'));
        _maybeScheduleReconnect(code: code, reason: reason, err: err);
      }
    });
  }

  /// Reporta open/close/error pro servidor (cai no log do Cloud Run, onde dá
  /// pra inspecionar `coach.live.client_diag is1008=true`). Best-effort.
  Future<void> _beacon(
    String phase, {
    int? code,
    String? reason,
    String? error,
  }) async {
    try {
      await _dio.post<void>('/coach/live-diag', data: {
        'phase': phase,
        'code': ?code,
        'reason': ?reason,
        'error': ?error,
        'sysInstrLen': _lastConfig?.systemInstruction?.length ?? 0,
        'outputTranscription': _lastConfig?.outputTranscription ?? false,
        'model': _lastConfig?.model,
        'runId': ?_runId,
        'generation': _ctxMgr.generation,
        'turns': _turnsThisSession,
        'ageMs': sessionAge.inMilliseconds,
        'attempt': phase == 'reconnect_attempt' ? _reconnectAttempt : null,
      });
    } catch (_) {/* diagnóstico é best-effort */}
  }

  void _onMessage(LiveServerMessage msg) {
    final sc = msg.serverContent;

    // Áudio: acumula chunks PCM 24kHz. Web acumula localmente; nativo vai pro
    // buffer do speaker do LiveAudioService.
    final b64 = msg.data;
    if (b64 != null && b64.isNotEmpty) {
      final pcm = base64.decode(b64);
      if (kIsWeb) {
        _webPcm.add(pcm);
      } else {
        _audio.addSpeakerChunk(pcm);
      }
    }

    // Transcript do áudio de saída (texto == voz).
    final t = sc?.outputTranscription?.text;
    if (t != null && t.isNotEmpty) _turnTranscript.write(t);

    // Fim do turno: toca o áudio acumulado e publica o transcript da fala.
    if (sc?.turnComplete == true) {
      if (kIsWeb) {
        final pcm = _webPcm.takeBytes();
        if (pcm.isNotEmpty) {
          final wav = _pcmToWav(pcm, 24000);
          playCoachAudio(base64Encode(wav), mimeType: 'audio/wav');
        }
      } else {
        unawaited(_audio.flushAndPlay());
      }
      final spoken = _turnTranscript.toString().trim();
      _turnTranscript.clear();
      if (spoken.isNotEmpty) {
        _turnsThisSession += 1;
        final trigger = _currentTrigger ?? 'unknown';
        // Alimenta o manager ANTES de emitir no stream público — assim qualquer
        // rotação disparada pelo bloc imediatamente após já enxerga essa fala.
        final metrics = _lastMetricsCallback?.call();
        _ctxMgr.recordCoachTurn(
          text: spoken,
          trigger: trigger,
          metrics: metrics ?? const RunMetricsSnapshot(),
        );
        // Beacon fire-and-forget pra persistência server-side.
        final runId = _runId;
        if (runId != null) {
          unawaited(_beaconRemote.logCoachTurn(
            runId: runId,
            text: spoken,
            trigger: trigger,
            sessionGeneration: _ctxMgr.generation,
            metrics: metrics,
          ));
        }
        if (!_transcriptsCtrl.isClosed) {
          _transcriptsCtrl.add(spoken);
        }
      }
    }
  }

  /// O bloc registra um getter de métricas correntes — chamado quando um
  /// turn fecha pra carimbar o snapshot no manager + beacon.
  RunMetricsSnapshot Function()? _lastMetricsCallback;
  // ignore: use_setters_to_change_properties
  void setMetricsProvider(RunMetricsSnapshot Function() provider) {
    _lastMetricsCallback = provider;
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

  /// Envia uma atualização (largada/km/alerta/fim) → provoca uma fala curta.
  /// Se a sessão tiver caído, a mensagem fica enfileirada pra ser drenada
  /// quando a reconexão completar (preserva continuidade audível).
  void sendTelemetry(String text) {
    if (text.trim().isEmpty) return;
    if (_open) {
      try {
        _session?.sendText(text);
      } catch (e) {
        // ignore: avoid_print
        print('run.coach.live.send_failed: $e');
      }
      return;
    }
    // ignore: avoid_print
    print('run.coach.live.send_queued (reconnecting)');
    _pendingSends.add(text);
    // Garante que tem reconnect agendado (caso onClose tenha caído antes de
    // chegar aqui por timing).
    _maybeScheduleReconnect();
  }

  /// Abre janela de fala (push-to-talk): streama o mic pra sessão. NÃO usa
  /// sendActivityStart/End — com VAD automático (default) esses sinais dão
  /// erro; o modelo detecta início/fim de fala pelo próprio áudio.
  Future<void> startTalk() async {
    if (!_open) {
      // ignore: avoid_print
      print('run.coach.live.talk_skip reason=session_closed');
      return;
    }
    if (_talking) return;
    try {
      final ok = await _audio.requestMicPermission();
      // ignore: avoid_print
      print('run.coach.live.talk_perm granted=$ok');
      if (!ok) {
        unawaited(_beacon('talk_no_permission'));
        return;
      }
      await _audio.startCapture((chunk) {
        try {
          _session?.sendAudio(chunk);
        } catch (_) {/* ignore */}
      });
      _talking = true;
      _ctxMgr.recordUserPushToTalk();
      // ignore: avoid_print
      print('run.coach.live.talk_start ok');
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.talk_start_failed: $e');
      unawaited(_beacon('talk_error', error: e.toString()));
    }
  }

  /// Fecha a janela de fala → o VAD automático detecta o silêncio e o coach
  /// responde.
  Future<void> stopTalk() async {
    if (!_talking) return;
    _talking = false;
    try {
      await _audio.stopCapture();
      // ignore: avoid_print
      print('run.coach.live.talk_stop ok');
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.talk_stop_failed: $e');
    }
  }

  Future<void> close() async {
    _disposed = true;
    _open = false;
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pendingSends.clear();
    await stopTalk();
    try {
      await _session?.close();
    } catch (_) {/* ignore */}
    _session = null;
    await _audio.dispose();
    if (!_transcriptsCtrl.isClosed) await _transcriptsCtrl.close();
  }

  Future<_LiveCoachConfig?> _fetchConfig(String? planSessionId) async {
    try {
      // Snapshot de clima (se disponível) entra no systemInstruction da
      // sessão Live pro coach considerar calor/umidade/vento na fala —
      // sem impacto na UI da corrida ativa.
      final weather = locationWeatherController.weather;
      Logger.info('run.coach.live_token.weather_snapshot', context: {
        'present': weather != null,
        if (weather != null) 'tempC': weather.temperatureC,
        if (weather != null) 'humidity': weather.humidityPercent,
        if (weather != null) 'windKmh': weather.windKmh,
        if (weather != null)
          'ageMs': DateTime.now().difference(weather.fetchedAt).inMilliseconds,
      });
      final body = <String, dynamic>{
        'planSessionId': ?planSessionId,
        if (weather != null) ...{
          'temperatureC': weather.temperatureC,
          'humidityPercent': weather.humidityPercent,
          'windKmh': weather.windKmh,
        },
      };
      final res = await _dio.post<Map<String, dynamic>>(
        '/coach/live-token',
        data: body.isEmpty ? null : body,
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );
      final data = res.data;
      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) return null;
      // Server manda 'models/<id>'; o pacote conecta com o id sem prefixo.
      final rawModel = (data?['model'] as String?) ??
          'models/gemini-live-2.5-flash-native-audio';
      final model = rawModel.replaceFirst('models/', '');
      final expireRaw = data?['expireTime'] as String?;
      if (expireRaw != null) {
        _tokenExpiresAt = DateTime.tryParse(expireRaw)?.toUtc();
      }
      return _LiveCoachConfig(
        token: token,
        model: model,
        voice: (data?['voice'] as String?) ?? _voiceDefault,
        systemInstruction: data?['systemInstruction'] as String?,
        outputTranscription: (data?['outputTranscription'] as bool?) ?? false,
      );
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.config_failed: $e');
      return null;
    }
  }
}

class _LiveCoachConfig {
  _LiveCoachConfig({
    required this.token,
    required this.model,
    required this.voice,
    required this.systemInstruction,
    required this.outputTranscription,
  });

  final String token;
  final String model;
  final String voice;
  final String? systemInstruction;
  final bool outputTranscription;
}
