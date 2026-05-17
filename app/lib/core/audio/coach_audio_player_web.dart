// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

html.AudioElement? _currentCoachAudio;
bool _audioUnlocked = false;

/// Destrava autoplay do browser usando o user gesture corrente (deve
/// ser chamado dentro do onTap do botão INICIAR ou similar).
///
/// Sem essa "destrava", browsers modernos (Chrome 66+, Safari 11+,
/// Firefox 70+) bloqueiam `.play()` sem interação prévia — `playCoachAudio`
/// falha silenciosamente e user não ouve nada.
///
/// Estratégia: chama .play() em um AudioElement com 1 frame silencioso
/// WAV (44 bytes header + 0 payload). O browser marca o domínio como
/// "permitido autoplay" pra sessão inteira.
void unlockAudioContext() {
  if (_audioUnlocked) return;
  try {
    // WAV header mínimo: 1 sample mono 8kHz 8-bit silêncio.
    // Base64 pré-computado de 46 bytes (44 header + 2 sample silêncio).
    const silentWav =
        'UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=';
    final audio = html.AudioElement('data:audio/wav;base64,$silentWav')
      ..volume = 0
      ..muted = true;
    audio.play().then((_) {
      _audioUnlocked = true;
    }).catchError((_) {/* sem suporte ou bloqueado — segue tentando */});
  } catch (_) {/* segue, playCoachAudio vai logar se falhar */}
}

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

  // Erro mais comum aqui: NotAllowedError (autoplay bloqueado por falta
  // de user gesture). Log explícito em vez de catch silencioso pra
  // facilitar debug.
  await audio.play().catchError((err) {
    // ignore: avoid_print
    print('coach_audio.play_failed: $err — '
        'autoplay bloqueado? chame unlockAudioContext() no handler do INICIAR.');
  });
}
