import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gemini_live/gemini_live.dart';
import 'package:runnin/core/network/api_client.dart';

/// Cliente direto Gemini Live (sem proxy) pra cues curtos de voz durante
/// a corrida. One-shot por chamada: abre WS, envia texto, coleta chunks
/// de áudio até turnComplete, fecha e devolve WAV base64.
///
/// Auth via ephemeral token: app pede ao server (POST /coach/live-token),
/// server gera token efêmero via Google auth_tokens API e devolve. App
/// usa o token como apiKey + apiVersion='v1alpha' no LiveService. API key
/// real nunca sai do server.
///
/// Por que client-side direto:
///  - sem ida-e-volta pelo Cloud Run pra cada TTS (estava dando 504)
///  - usa o mesmo motor Live do chat modal (consistência de voz)
///  - permite multimodal nativo (audio in/out) em features futuras
class LiveCoachVoiceService {
  final Dio _dio;
  LiveCoachVoiceService({Dio? dio}) : _dio = dio ?? apiClient;

  static const _model = 'gemini-live-2.5-flash-preview';
  static const _voiceDefault = 'Charon'; // masculina firme; outras: Aoede/Kore

  /// Cache simples do último token. Reusa quando ainda válido (margem 1min).
  /// Cada token vale 30min e 1 uso de sessão — vamos pedir um por cue.
  String? _cachedToken;
  DateTime? _cachedExpire;

  Future<String?> _fetchEphemeralToken() async {
    final cached = _cachedToken;
    final exp = _cachedExpire;
    if (cached != null && exp != null && exp.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return cached;
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/coach/live-token',
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );
      final token = res.data?['token'] as String?;
      final exp = res.data?['expireTime'] as String?;
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        _cachedExpire = exp != null ? DateTime.tryParse(exp) : null;
        return token;
      }
    } catch (_) {/* sem token → retorna null, sem áudio */}
    return null;
  }

  /// Sintetiza áudio do texto recebido via Gemini Live. Retorna
  /// `{wavBase64, mimeType}` ou null se Live indisponível/falhar.
  /// Timeout total 15s — pra não travar o /run.
  Future<LiveSynthesisResult?> synthesize(
    String text, {
    String? voiceId,
  }) async {
    if (text.trim().isEmpty) return null;
    final token = await _fetchEphemeralToken();
    if (token == null) return null;

    final pcmChunks = <Uint8List>[];
    final completer = Completer<void>();
    LiveSession? session;

    try {
      // Ephemeral tokens exigem apiVersion 'v1alpha' (vide docs do package).
      session = await LiveService(apiKey: token, apiVersion: 'v1alpha')
          .connect(
        LiveConnectParameters(
          model: _model,
          config: GenerationConfig(
            responseModalities: [Modality.AUDIO],
            speechConfig: SpeechConfig(
              voiceConfig: VoiceConfig(
                prebuiltVoiceConfig: PrebuiltVoiceConfig(
                  voiceName: voiceId ?? _voiceDefault,
                ),
              ),
            ),
          ),
          callbacks: LiveCallbacks(
            onOpen: () {},
            onMessage: (msg) {
              final b64 = msg.data;
              if (b64 != null) {
                pcmChunks.add(base64.decode(b64));
              }
              if (msg.serverContent?.turnComplete == true &&
                  !completer.isCompleted) {
                completer.complete();
              }
            },
            onError: (err, _) {
              if (!completer.isCompleted) completer.completeError(err);
            },
            onClose: (code, reason) {
              if (!completer.isCompleted) {
                if (pcmChunks.isEmpty) {
                  completer.completeError(
                    StateError('live_closed code=$code reason=$reason no chunks'),
                  );
                } else {
                  completer.complete();
                }
              }
            },
          ),
        ),
      );

      session.sendText(text);

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (pcmChunks.isEmpty) throw TimeoutException('live_timeout_15s');
        },
      );

      if (pcmChunks.isEmpty) return null;
      final totalLen = pcmChunks.fold<int>(0, (s, c) => s + c.length);
      final pcm = Uint8List(totalLen);
      var off = 0;
      for (final c in pcmChunks) {
        pcm.setRange(off, off + c.length, c);
        off += c.length;
      }
      // Gemini Live output: PCM 16-bit signed LE mono @ 24kHz.
      final wav = addWavHeader(pcm, sampleRate: 24000);
      return LiveSynthesisResult(
        audioBase64: base64Encode(wav),
        mimeType: 'audio/wav',
      );
    } catch (_) {
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }
}

class LiveSynthesisResult {
  final String audioBase64;
  final String mimeType;
  const LiveSynthesisResult({
    required this.audioBase64,
    required this.mimeType,
  });
}
