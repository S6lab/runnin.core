import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:runnin/core/logger/logger.dart';

/// Player nativo (iOS/Android) pro áudio do coach Gemini Live.
///
/// Web tem implementação própria em [coach_audio_player_web.dart] (HTMLAudioElement
/// com unlock por gesto). Mobile usa o package `audioplayers` direto — sem
/// necessidade de unlock por gesto (iOS só exige isso em browser).
///
/// AudioContext: category `.playback` + `mixWithOthers` + `duckOthers` (mesmo
/// padrão do [LiveAudioService] e [WorkoutRealtimePlugin]). Sem isso, silent
/// switch do iOS muta o coach e música de outros apps stoppa em vez de duck.

final AudioPlayer _player = AudioPlayer();
bool _contextConfigured = false;

Future<void> _ensureContext() async {
  if (_contextConfigured) return;
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
    _contextConfigured = true;
    Logger.info('coach_audio.context_configured');
  } catch (e, st) {
    Logger.error('coach_audio.context_config_failed', e, st);
  }
}

Future<void> playCoachAudio(
  String audioBase64, {
  String mimeType = 'audio/mpeg',
  double volume = 1.0,
  int? maxDurationMs,
}) async {
  if (audioBase64.trim().isEmpty) return;
  await _ensureContext();

  Uint8List bytes;
  try {
    bytes = base64Decode(audioBase64);
  } catch (e, st) {
    Logger.error('coach_audio.decode_failed', e, st);
    return;
  }

  try {
    await _player.stop();
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.play(BytesSource(bytes, mimeType: mimeType));
    Logger.info('coach_audio.play_started', context: {
      'bytes': bytes.length,
      'mime': mimeType,
    });
  } catch (e, st) {
    Logger.error('coach_audio.play_failed', e, st, {
      'bytes': bytes.length,
      'mime': mimeType,
    });
    return;
  }

  if (maxDurationMs != null && maxDurationMs > 0) {
    Timer(Duration(milliseconds: maxDurationMs), () {
      _player.stop().catchError((_) {});
    });
  }
}

/// Para o player imediatamente. TF 70: PrepPage chama ao navegar pra
/// /run pra evitar 2 áudios sobrepostos (pre_run ainda tocando quando
/// saudação da run dispara — "2 coaches simultâneos").
Future<void> stopCoachAudio() async {
  try {
    await _player.stop();
  } catch (_) {/* best-effort */}
}

/// No-op em mobile — destrava autoplay só faz sentido em web.
void unlockAudioContext() {}
