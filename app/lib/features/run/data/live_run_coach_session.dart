import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gemini_live/gemini_live.dart';
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
  bool _open = false;
  bool _talking = false;

  /// Cada item é o transcript de UMA fala completa do coach (texto == voz).
  Stream<String> get transcripts => _transcriptsCtrl.stream;
  bool get isOpen => _open;
  bool get isTalking => _talking;

  /// Abre a sessão. Retorna false se não conseguiu (cai pra run sem voz).
  Future<bool> open({String? planSessionId}) async {
    if (_open) return true;
    final cfg = await _fetchConfig(planSessionId);
    if (cfg == null) return false;
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
            },
            onClose: (code, reason) {
              // ignore: avoid_print
              print('run.coach.live.close code=$code reason=$reason');
              _open = false;
            },
          ),
        ),
      );
      _open = true;
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.open_failed: $e');
      return false;
    }
  }

  void _onMessage(LiveServerMessage msg) {
    final sc = msg.serverContent;

    // Áudio: acumula chunks PCM 24kHz pro speaker.
    final b64 = msg.data;
    if (b64 != null && b64.isNotEmpty) {
      _audio.addSpeakerChunk(base64.decode(b64));
    }

    // Transcript do áudio de saída (texto == voz).
    final t = sc?.outputTranscription?.text;
    if (t != null && t.isNotEmpty) _turnTranscript.write(t);

    // Fim do turno: toca o áudio acumulado e publica o transcript da fala.
    if (sc?.turnComplete == true) {
      unawaited(_audio.flushAndPlay());
      final spoken = _turnTranscript.toString().trim();
      _turnTranscript.clear();
      if (spoken.isNotEmpty && !_transcriptsCtrl.isClosed) {
        _transcriptsCtrl.add(spoken);
      }
    }
  }

  /// Envia uma atualização (largada/km/alerta/fim) → provoca uma fala curta.
  void sendTelemetry(String text) {
    if (!_open || text.trim().isEmpty) return;
    try {
      _session?.sendText(text);
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.send_failed: $e');
    }
  }

  /// Abre janela de fala (wake word "coach"): streama o mic pra sessão.
  Future<void> startTalk() async {
    if (!_open || _talking) return;
    try {
      final ok = await _audio.requestMicPermission();
      if (!ok) return;
      _session?.sendActivityStart();
      await _audio.startCapture((chunk) {
        try {
          _session?.sendAudio(chunk);
        } catch (_) {/* ignore */}
      });
      _talking = true;
    } catch (e) {
      // ignore: avoid_print
      print('run.coach.live.talk_start_failed: $e');
    }
  }

  /// Fecha a janela de fala → o coach responde e volta a narrar.
  Future<void> stopTalk() async {
    if (!_talking) return;
    _talking = false;
    try {
      await _audio.stopCapture();
      _session?.sendAudioStreamEnd();
      _session?.sendActivityEnd();
    } catch (_) {/* ignore */}
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
