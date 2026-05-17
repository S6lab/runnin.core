Future<void> playCoachAudio(
  String audioBase64, {
  String mimeType = 'audio/mpeg',
  double volume = 1.0,
  int? maxDurationMs,
}) async {}

/// No-op em mobile — destrava autoplay só faz sentido em web.
void unlockAudioContext() {}
