// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

html.AudioElement? _currentCoachAudio;

Future<void> playCoachAudio(
  String audioBase64, {
  String mimeType = 'audio/mpeg',
  double volume = 1.0,
  int? maxDurationMs,
}) async {
  if (audioBase64.trim().isEmpty) return;

  // Stop previous audio if present
  try {
    _currentCoachAudio?.pause();
    _currentCoachAudio?.src = '';
  } catch (_) {}

  final audio = html.AudioElement('data:$mimeType;base64,$audioBase64')
    ..autoplay = true
    ..volume = volume.clamp(0.0, 1.0);

  _currentCoachAudio = audio;

  Timer? truncTimer;
  if (maxDurationMs != null && maxDurationMs > 0) {
    truncTimer = Timer(Duration(milliseconds: maxDurationMs), () {
      if (_currentCoachAudio == audio) {
        try {
          audio.pause();
          audio.currentTime = 0;
        } catch (_) {}
        _currentCoachAudio = null;
      }
    });
  }

  audio.onEnded.listen((_) {
    truncTimer?.cancel();
    if (_currentCoachAudio == audio) _currentCoachAudio = null;
  });

  await audio.play().catchError((_) {});
}
