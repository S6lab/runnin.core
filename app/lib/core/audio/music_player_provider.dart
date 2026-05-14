import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'music_player_service.dart';

final musicPlayerServiceProvider = Provider<_MusicPlayerProvider>((ref) {
  return _MusicPlayerProvider();
});

class _MusicPlayerProvider extends MusicPlayerService {
  bool _duckingEnabled = true;
  
  @override
  set duckingEnabled(bool value) {
    _duckingEnabled = value;
    // When ducking is enabled, audio session automatically reduces music
    // volume when coach voice plays
  }
  
  bool get duckingEnabled => _duckingEnabled;
}
