import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// TF 75 Fase 0 (CRÍTICO): wrapper do AudioSessionPlugin nativo iOS.
/// Mantém AVAudioSession ATIVA via silent audio loop durante a corrida
/// pra Dart engine não suspender em background — Eduardo TF 74 reportou
/// cues parando após 5min com iPhone bloqueado.
///
/// No-op em Android/Web (ainda não implementado lá; Watch é iOS-only).
class AudioSessionKeepalive {
  AudioSessionKeepalive._();
  static final instance = AudioSessionKeepalive._();

  static const _channel = MethodChannel('runnin/audio_session');

  Future<void> startKeepalive() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<Object>('startKeepalive');
    } on PlatformException {
      // Best-effort: se o plugin não está disponível (Android), só ignora.
    } on MissingPluginException {
      // Esperado em platforms sem o plugin.
    }
  }

  Future<void> stopKeepalive() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<Object>('stopKeepalive');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
