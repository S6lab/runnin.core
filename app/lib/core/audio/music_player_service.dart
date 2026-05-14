import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MusicPlayerService {
  static final MusicPlayerService _instance = MusicPlayerService._internal();

  factory MusicPlayerService() => _instance;

  MusicPlayerService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _duckingEnabled = true;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    
    _audioPlayer = AudioPlayer();
    _isInitialized = true;
  }

  Future<void> playUrl(String url) async {
    await initialize();
    try {
      final source = AudioSource.uri(Uri.parse(url));
      await _audioPlayer?.setAudioSource(source);
      
      if (_duckingEnabled) {
        await session.setActive(false);
        await session.setActive(true, options: {
          AudioStateHoldingBehavior.stopOtherBecomingSilent: true
        });
      }
      
      await _audioPlayer!.play();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  Future<void> playAsset(String asset) async {
    await initialize();
    try {
      final source = AudioSource.asset(asset);
      await _audioPlayer?.setAudioSource(source);
      
      if (_duckingEnabled) {
        final session = await AudioSession.instance;
        await session.setActive(false);
        await session.setActive(true, options: {
          AudioStateHoldingBehavior.stopOtherBecomingSilent: true
        });
      }
      
      await _audioPlayer!.play();
    } catch (e) {
      throw Exception('Failed to play asset: $e');
    }
  }

  Future<void> pause() async {
    if (_audioPlayer != null && _audioPlayer!.playing) {
      await _audioPlayer!.pause();
    }
  }

  Future<void> resume() async {
    if (_audioPlayer != null && !_audioPlayer!.playing) {
      await _audioPlayer!.play();
    }
  }

  Future<void> stop() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
    }
  }

  Future<void> setVolume(double volume) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.setVolume(volume.clamp(0.0, 1.0));
    }
  }

  double? get volume => _audioPlayer?.volume;

  bool get isPlaying => _audioPlayer?.playing ?? false;

  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _isInitialized = false;
  }

  set duckingEnabled(bool value) {
    _duckingEnabled = value;
    final session = AudioSession.instance;
  }

  bool get duckingEnabled => _duckingEnabled;
}
