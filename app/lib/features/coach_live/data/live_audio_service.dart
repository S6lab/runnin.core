import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'package:runnin/core/logger/logger.dart';

/// Audio I/O para sessão Coach Live com Gemini.
///
/// Mic:  captura PCM 16-bit mono @ 16kHz (formato esperado pelo Gemini Live)
///       e expõe via [onChunk] — caller envia pelo WebSocket.
/// Speaker: recebe chunks PCM 16-bit mono @ 24kHz (default do Gemini Live),
///          acumula no buffer e toca como WAV via [flushAndPlay].
class LiveAudioService {
  LiveAudioService() {
    _configureAudioContext();
  }

  static const _micSampleRate = 16000;
  static const _speakerSampleRate = 24000;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  StreamSubscription<Uint8List>? _micSub;
  final _speakerBuffer = BytesBuilder();
  bool _recording = false;
  bool _audioContextConfigured = false;

  bool get isRecording => _recording;

  /// Configura AVAudioSession (iOS) / AudioFocus (Android) pra category
  /// `.playback`. Sem isso, o áudio do coach é silenciado quando o silent
  /// switch está ativado (iOS default = soloAmbient), ou abafado quando
  /// outro app está tocando música. `mixWithOthers` permite coexistir com
  /// Spotify/Apple Music sem stop.
  Future<void> _configureAudioContext() async {
    if (_audioContextConfigured) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistanceNavigationGuidance,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      _audioContextConfigured = true;
      Logger.info('live_audio.context_configured');
    } catch (e, st) {
      Logger.error('live_audio.context_config_failed', e, st);
    }
  }

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
    } catch (e, st) {
      Logger.warn('live_audio.recorder_stop_failed', context: {'err': '$e'});
      Logger.info('live_audio.recorder_stop_stack', context: {'st': st.toString().split('\n').first});
    }
  }

  /// Acumula chunk PCM 16-bit @ 24kHz recebido do server.
  void addSpeakerChunk(Uint8List pcmChunk) {
    _speakerBuffer.add(pcmChunk);
  }

  /// Envolve buffer acumulado num header WAV e toca; depois limpa o buffer.
  Future<void> flushAndPlay() async {
    if (_speakerBuffer.isEmpty) return;
    // Garante que o AudioContext está configurado (idempotente).
    await _configureAudioContext();
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
      // mimeType OBRIGATÓRIO no iOS: audioplayers escreve os bytes em
      // tempDir sem extensão → sem mimeType, AVPlayer não consegue inferir
      // o formato e estoura "Failed to set playerItem". Com mimeType,
      // AVURLAssetOverrideMIMETypeKey força a decodificação WAV.
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
      Logger.info('live_audio.played', context: {'wav_bytes': wav.length});
    } catch (e, st) {
      Logger.error('live_audio.play_failed', e, st, {'wav_bytes': wav.length});
    }
  }

  bool _disposed = false;

  Future<void> dispose() async {
    // Idempotente — coach_session pode chamar close() múltiplas vezes
    // (finish trigger + safety timer + abandon). Sem essa guarda, o 2º
    // dispose lança "Player has not yet been created or has already been
    // disposed." e quebra o flush final da corrida.
    if (_disposed) return;
    _disposed = true;
    await stopCapture();
    try {
      await _player.dispose();
    } catch (_) {/* já disposed pelo plugin nativo */}
    try {
      _recorder.dispose();
    } catch (_) {/* idem */}
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
