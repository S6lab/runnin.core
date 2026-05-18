// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Audio element PERSISTENTE — criado no gesto INICIAR e reusado pra
/// cada cue. iOS Safari/Chrome (que usa WebKit) só permite play sem
/// gesture se for em element que JÁ tocou algo durante um gesture.
/// Trocar `src` de um element "destravado" funciona; criar novo element
/// fora do gesture NÃO funciona em iOS.
html.AudioElement? _persistentAudio;
String? _currentObjectUrl;
bool _audioUnlocked = false;

void _ensureElement() {
  if (_persistentAudio != null) return;
  // Cria o element uma vez, com src vazio. Será preenchido depois.
  _persistentAudio = html.AudioElement()
    ..preload = 'auto'
    ..crossOrigin = 'anonymous';
}

void unlockAudioContext() {
  if (_audioUnlocked) return;
  try {
    _ensureElement();
    // WAV silente mínimo: 1 sample 8-bit @ 8kHz.
    const silentB64 =
        'UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=';
    final bytes = base64Decode(silentB64);
    final blob = html.Blob([Uint8List.fromList(bytes)], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);
    _persistentAudio!
      ..muted = true
      ..volume = 0
      ..src = url;
    // play() DENTRO do gesto destrava o element pra plays futuros.
    _persistentAudio!.play().then((_) {
      _audioUnlocked = true;
      // ignore: avoid_print
      print('coach_audio.unlocked');
      // Não revoga url ainda — o element pode ainda estar referenciando.
      // Revoga no próximo play().
      _currentObjectUrl = url;
    }).catchError((err) {
      // ignore: avoid_print
      print('coach_audio.unlock_failed: $err');
      try { html.Url.revokeObjectUrl(url); } catch (_) {}
    });
  } catch (e) {
    // ignore: avoid_print
    print('coach_audio.unlock_exception: $e');
  }
}

Future<void> playCoachAudio(
  String audioBase64, {
  String mimeType = 'audio/mpeg',
  double volume = 1.0,
  int? maxDurationMs,
}) async {
  if (audioBase64.trim().isEmpty) return;

  _ensureElement();
  final audio = _persistentAudio!;

  // Pause previous + revoke URL anterior pra evitar memory leak.
  try {
    audio.pause();
  } catch (_) {}
  if (_currentObjectUrl != null) {
    try {
      html.Url.revokeObjectUrl(_currentObjectUrl!);
    } catch (_) {}
    _currentObjectUrl = null;
  }

  // Blob URL (data URL fica gigante e iOS recusa >2MB em <audio>).
  final bytes = base64Decode(audioBase64);
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  _currentObjectUrl = url;

  audio
    ..muted = false
    ..volume = volume.clamp(0.0, 1.0)
    ..src = url;

  Timer? truncTimer;
  if (maxDurationMs != null && maxDurationMs > 0) {
    truncTimer = Timer(Duration(milliseconds: maxDurationMs), () {
      try {
        audio.pause();
        audio.currentTime = 0;
      } catch (_) {}
    });
  }

  StreamSubscription? endedSub;
  endedSub = audio.onEnded.listen((_) {
    truncTimer?.cancel();
    endedSub?.cancel();
  });

  StreamSubscription? errSub;
  errSub = audio.onError.listen((e) {
    // ignore: avoid_print
    print('coach_audio.element_error code=${audio.error?.code} msg=${audio.error?.message}');
    errSub?.cancel();
  });

  // iOS quer canplaythrough antes de play() pra evitar NotSupportedError.
  // Timeout 3s — em conexões boas vem em <500ms.
  try {
    await audio.onCanPlayThrough.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => html.Event('timeout'),
    );
  } catch (_) {/* segue mesmo sem evento */}

  try {
    await audio.play();
    // ignore: avoid_print
    print('coach_audio.play_started bytes=${bytes.length}');
  } catch (err) {
    // ignore: avoid_print
    print('coach_audio.play_failed: $err — element unlocked=$_audioUnlocked');
  }
}
