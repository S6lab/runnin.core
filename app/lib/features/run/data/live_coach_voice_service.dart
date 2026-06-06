import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gemini_live/gemini_live.dart';
import 'package:runnin/core/network/api_client.dart';

/// Cliente Gemini Live via EPHEMERAL TOKEN direto no Google.
///
/// Por que não proxy: `BidiGenerateContent` plain está sendo rejeitado
/// pelo Google em todos os modelos testados ("not found for API version
/// v1beta"). O único endpoint vivo é `BidiGenerateContentConstrained`
/// (v1alpha) que EXIGE ephemeral token. Esse é o caminho recomendado
/// pela documentação atual (2025-2026).
///
/// Estratégia: server cria token via auth_tokens com constraint COMPLETO
/// (modelo + modalities + voiceConfig). App passa o token como apiKey
/// no LiveService E envia config IGUAL ao constraint — assim Google
/// aceita o setup e retorna setupComplete.
class LiveCoachVoiceService {
  final Dio _dio;
  LiveCoachVoiceService({Dio? dio}) : _dio = dio ?? apiClient;

  // PRECISA bater com DEFAULT_MODEL em create-live-ephemeral-token.use-case.ts
  // Native-audio é o modelo Live oficial pra AUDIO modality em bidi.
  // gemini-live-2.5-flash-preview suporta TEXT mas não AUDIO no bidi.
  static const _model = 'gemini-live-2.5-flash-native-audio';
  static const _voiceDefault = 'Charon';

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
      final expStr = res.data?['expireTime'] as String?;
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        _cachedExpire = expStr != null ? DateTime.tryParse(expStr) : null;
        // ignore: avoid_print
        print('coach.live.token.fetched len=${token.length} exp=$expStr');
        return token;
      }
      // ignore: avoid_print
      print('coach.live.token.empty data=${res.data}');
    } catch (e) {
      // ignore: avoid_print
      print('coach.live.token.fetch_failed: $e');
    }
    return null;
  }

  Future<LiveSynthesisResult?> synthesize(String text) async {
    if (text.trim().isEmpty) return null;
    var result = await _trySynthesize(text);
    if (result == null && _cachedToken != null) {
      _cachedToken = null;
      _cachedExpire = null;
      result = await _trySynthesize(text);
    }
    return result;
  }

  Future<LiveSynthesisResult?> _trySynthesize(String text) async {
    final token = await _fetchEphemeralToken();
    if (token == null) return null;

    final pcmChunks = <Uint8List>[];
    final completer = Completer<void>();
    LiveSession? session;

    try {
      // ignore: avoid_print
      print('coach.live.connect.attempt model=$_model voice=$_voiceDefault');
      // Ephemeral tokens exigem apiVersion 'v1alpha'.
      // Config MATCH com o que o server declarou no auth_tokens body
      // (responseModalities AUDIO + speechConfig.voiceConfig).
      session = await LiveService(apiKey: token, apiVersion: 'v1alpha')
          .connect(
        LiveConnectParameters(
          model: _model,
          config: GenerationConfig(
            responseModalities: [Modality.AUDIO],
            speechConfig: SpeechConfig(
              voiceConfig: VoiceConfig(
                prebuiltVoiceConfig: PrebuiltVoiceConfig(
                  voiceName: _voiceDefault,
                ),
              ),
            ),
          ),
          callbacks: LiveCallbacks(
            onOpen: () {
              // ignore: avoid_print
              print('coach.live.ws.open');
            },
            onMessage: (msg) {
              final b64 = msg.data;
              if (b64 != null) {
                pcmChunks.add(base64.decode(b64));
              }
              if (msg.serverContent?.turnComplete == true &&
                  !completer.isCompleted) {
                // ignore: avoid_print
                print('coach.live.ws.turn_complete chunks=${pcmChunks.length}');
                completer.complete();
              }
            },
            onError: (err, _) {
              // ignore: avoid_print
              print('coach.live.ws.callback_error: $err');
              if (!completer.isCompleted) completer.completeError(err);
            },
            onClose: (code, reason) {
              // ignore: avoid_print
              print('coach.live.ws.close code=$code reason=$reason chunks=${pcmChunks.length}');
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

      // ignore: avoid_print
      print('coach.live.send_text len=${text.length}');
      session.sendText(text);

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // ignore: avoid_print
          print('coach.live.timeout_15s chunks=${pcmChunks.length}');
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
      final wav = _pcmToWav(pcm, sampleRate: 24000);
      // ignore: avoid_print
      print('coach.live.synthesize.ok chunks=${pcmChunks.length} bytes=$totalLen');
      return LiveSynthesisResult(
        audioBase64: base64Encode(wav),
        mimeType: 'audio/wav',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('coach.live.synthesize.failed: $e\n$st');
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }
}

Uint8List _pcmToWav(Uint8List pcm, {required int sampleRate}) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLen = pcm.length;
  final riffLen = 36 + dataLen;
  final header = ByteData(44);
  header.setUint8(0, 0x52); header.setUint8(1, 0x49);
  header.setUint8(2, 0x46); header.setUint8(3, 0x46);
  header.setUint32(4, riffLen, Endian.little);
  header.setUint8(8, 0x57); header.setUint8(9, 0x41);
  header.setUint8(10, 0x56); header.setUint8(11, 0x45);
  header.setUint8(12, 0x66); header.setUint8(13, 0x6d);
  header.setUint8(14, 0x74); header.setUint8(15, 0x20);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  header.setUint8(36, 0x64); header.setUint8(37, 0x61);
  header.setUint8(38, 0x74); header.setUint8(39, 0x61);
  header.setUint32(40, dataLen, Endian.little);
  final out = Uint8List(44 + dataLen);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, 44 + dataLen, pcm);
  return out;
}

class LiveSynthesisResult {
  final String audioBase64;
  final String mimeType;
  const LiveSynthesisResult({
    required this.audioBase64,
    required this.mimeType,
  });
}
