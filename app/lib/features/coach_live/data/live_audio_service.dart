import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Audio I/O para sessão Coach Live com Gemini.
///
/// Mic:  captura PCM 16-bit mono @ 16kHz (formato esperado pelo Gemini Live)
///       e expõe via [onChunk] — caller envia pelo WebSocket.
/// Speaker: recebe chunks PCM 16-bit mono @ 24kHz (default do Gemini Live),
///          acumula no buffer e toca como WAV via [flushAndPlay].
class LiveAudioService {
  LiveAudioService();

  static const _micSampleRate = 16000;
  static const _speakerSampleRate = 24000;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  StreamSubscription<Uint8List>? _micSub;
  final _speakerBuffer = BytesBuilder();
  bool _recording = false;

  bool get isRecording => _recording;

  /// Verifica + pede permissão de microfone.
  Future<bool> requestMicPermission() => _recorder.hasPermission();

  /// Começa a captura. [onChunk] é chamado a cada bloco PCM 16kHz mono recebido.
  Future<void> startCapture(void Function(Uint8List pcmChunk) onChunk) async {
    if (_recording) return;
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw StateError('Sem permissão de microfone');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _micSampleRate,
        numChannels: 1,
      ),
    );
    _recording = true;
    _micSub = stream.listen(
      onChunk,
      onError: (_) => stopCapture(),
      onDone: () => _recording = false,
    );
  }

  Future<void> stopCapture() async {
    if (!_recording) return;
    _recording = false;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // ignore
    }
  }

  /// Acumula chunk PCM 16-bit @ 24kHz recebido do server.
  void addSpeakerChunk(Uint8List pcmChunk) {
    _speakerBuffer.add(pcmChunk);
  }

  /// Envolve buffer acumulado num header WAV e toca; depois limpa o buffer.
  Future<void> flushAndPlay() async {
    if (_speakerBuffer.isEmpty) return;
    final pcm = _speakerBuffer.toBytes();
    _speakerBuffer.clear();
    final wav = _wrapPcmAsWav(
      pcm,
      sampleRate: _speakerSampleRate,
      bitsPerSample: 16,
      channels: 1,
    );
    try {
      await _player.stop();
      await _player.play(BytesSource(wav));
    } catch (_) {
      // ignore
    }
  }

  Future<void> dispose() async {
    await stopCapture();
    await _player.dispose();
    _recorder.dispose();
  }

  /// Constrói header WAV (RIFF) pra reprodução de PCM raw.
  static Uint8List _wrapPcmAsWav(
    Uint8List pcm, {
    required int sampleRate,
    required int bitsPerSample,
    required int channels,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final chunkSize = 36 + dataSize;

    final header = ByteData(44);
    // RIFF chunk
    _writeStr(header, 0, 'RIFF');
    header.setUint32(4, chunkSize, Endian.little);
    _writeStr(header, 8, 'WAVE');
    // fmt subchunk
    _writeStr(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // subchunk1 size (PCM)
    header.setUint16(20, 1, Endian.little); // audio format: PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data subchunk
    _writeStr(header, 36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, 44 + dataSize, pcm);
    return out;
  }

  static void _writeStr(ByteData bd, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bd.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
