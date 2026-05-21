import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gemini_live/gemini_live.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/coach_live/data/live_audio_service.dart';

/// Sessão Gemini Live nativa ÚNICA que acompanha a corrida inteira
/// (Doc 5 §XIV — "Voz ao Vivo"). É o único cérebro do coach na run:
///
/// - Abre 1x no início (com o systemInstruction travado pelo servidor:
///   objetivo + mood + sessão + segments) e fica aberta até o fim.
/// - A cada momento-chave (largada, km, alerta, fim) o caller chama
///   [sendTelemetry] → o modelo responde com UM feedback curto em áudio.
/// - `outputAudioTranscription` ligado → expõe o transcript do que foi
///   FALADO via [transcripts], garantindo texto == voz no banner.
/// - Áudio toca pelo [LiveAudioService] (audioplayers), que funciona no
///   mobile — onde o player web era no-op.
/// - [startTalk]/[stopTalk] abrem uma janela de fala (wake word "coach"):
///   streama o mic pra sessão já aberta e volta a narrar.
class LiveRunCoachSession {
  LiveRunCoachSession({Dio? dio, LiveAudioService? audio})
      : _dio = dio ?? apiClient,
        _audio = audio ?? LiveAudioService();

  final Dio _dio;
  final LiveAudioService _audio;

  static const _voiceDefault = 'Charon';

  LiveSession? _session;
  final _transcriptsCtrl = StreamController<String>.broadcast();
  final StringBuffer _turnTranscript = StringBuffer();
  // Web: acumula o PCM do turno e toca pelo <audio> persistente (desbloqueado
  // no INICIAR). audioplayers não fica desbloqueado no Chrome mobile.
  final BytesBuilder _webPcm = BytesBuilder();
  bool _open = false;
  bool _talking = false;

  // Snapshot da config pra anexar nos beacons de diagnóstico (rastrear 1008)
  // e pra reabrir a sessão se o Gemini Live encerrar por limite de duração.
  String? _model;
  int _sysInstrLen = 0;
  bool _outTranscript = false;
  String? _runId;
  String? _planSessionId;
  bool _reopening = false;

  /// Cada item é o transcript de UMA fala completa do coach (texto == voz).
  Stream<String> get transcripts => _transcriptsCtrl.stream;
  bool get isOpen => _open;
  bool get isTalking => _talking;

  /// Abre a sessão. Retorna false se não conseguiu (cai pra run sem voz).
  Future<bool> open({String? planSessionId, String? runId}) async {
    if (_open) return true;
    _runId = runId;
    _planSessionId = planSessionId;
    final cfg = await _fetchConfig(planSessionId);
    if (cfg == null) return false;
    _model = cfg.model;
    _sysInstrLen = cfg.systemInstruction?.length ?? 0;
    _outTranscript = cfg.outputTranscription;
    try {
      _session = await LiveService(apiKey: cfg.token, apiVersion: 'v1alpha')
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
          // Mesmo texto que o servidor travou na constraint do token.
          systemInstruction: cfg.systemInstruction != null
              ? Content(parts: [Part(text: cfg.systemInstruction!)])
              : null,
          outputAudioTranscription:
              cfg.outputTranscription ? AudioTranscriptionConfig() : null,
          callbacks: LiveCallbacks(
            onMessage: _onMessage,
            onError: (err, _) {
              // ignore: avoid_print
              print('run.coach.live.error: $err');
              unawaited(_beacon('ws_error', error: err.toString()));
            },
            onClose: (code, reason) {
              final is1008 = code == 1008;
              // ignore: avoid_print
              print('run.coach.live.close code=$code reason=$reason is1008=$is1008 sysInstrLen=$_sysInstrLen outTranscript=$_outTranscript');
              _open = false;
              unawaited(_beacon('ws_close', code: code, reason: reason));
            },
          ),
        ),
      );
      _open = true;
      // ignore: avoid_print
      print('run.coach.live.open_ok model=$_model sysInstrLen=$_sysInstrLen outTranscript=$_outTranscript');
      unawaited(_beacon('open_ok'));
      return true;
    } catch (e) {
      // open_failed costuma ser o 1008 de SETUP (systemInstruction grande na
      // constraint / safety) — o connect() lança antes do setupComplete.
      // ignore: avoid_print
      print('run.coach.live.open_failed: $e sysInstrLen=$_sysInstrLen outTranscript=$_outTranscript');
      unawaited(_beacon('open_failed', error: e.toString()));
      return false;
    }
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
        'sysInstrLen': _sysInstrLen,
        'outputTranscription': _outTranscript,
        'model': _model,
        'runId': ?_runId,
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
        // Web: monta WAV e toca pelo <audio> persistente (desbloqueado no
        // INICIAR via unlockAudioContext) — funciona no Chrome mobile.
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
      if (spoken.isNotEmpty && !_transcriptsCtrl.isClosed) {
        _transcriptsCtrl.add(spoken);
      }
    }
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
  /// Se a sessão tiver caído (limite de duração do Gemini Live), reabre antes
  /// de mandar — assim a voz não morre depois de alguns minutos de corrida.
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
    print('run.coach.live.reopen_for_send');
    unawaited(_reopenAndSend(text));
  }

  Future<void> _reopenAndSend(String text) async {
    if (_reopening) return;
    _reopening = true;
    try {
      final ok = await open(planSessionId: _planSessionId, runId: _runId);
      if (ok) _session?.sendText(text);
    } finally {
      _reopening = false;
    }
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
    _open = false;
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
      final res = await _dio.post<Map<String, dynamic>>(
        '/coach/live-token',
        data: planSessionId != null ? {'planSessionId': planSessionId} : null,
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );
      final data = res.data;
      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) return null;
      // Server manda 'models/<id>'; o pacote conecta com o id sem prefixo.
      final rawModel = (data?['model'] as String?) ??
          'models/gemini-2.5-flash-native-audio-preview-12-2025';
      final model = rawModel.replaceFirst('models/', '');
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
