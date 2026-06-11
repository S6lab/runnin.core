import 'package:flutter_tts/flutter_tts.dart';

/// TTS on-device pro modo FREEMIUM. Fala uma linha curta de telemetria
/// (pace + tempo + distância) a cada km — sem hit no backend, sem voz
/// AI. Premium continua via [LiveRunCoachSession] (Gemini Live).
///
/// Singleton lazy: instancia o engine na primeira call, reusa pra
/// próximas. iOS/Android/Web compartilham a mesma API. Falhas (engine
/// indisponível, voz não baixada) são silenciosas — UI ainda mostra o
/// banner via [coachLiveMessage] no [RunState].
class TelemetryTts {
  TelemetryTts._();
  static final TelemetryTts instance = TelemetryTts._();

  FlutterTts? _tts;
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      final t = FlutterTts();
      await t.setLanguage('pt-BR');
      await t.setSpeechRate(0.5);
      await t.setVolume(1.0);
      await t.setPitch(1.0);
      // iOS: pausa música ambiente durante a fala, depois retoma.
      // Mesmo gesto de "ducking" que o Coach Live usa.
      try {
        await t.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      } catch (_) {/* não-iOS ou versão antiga, ok */}
      _tts = t;
      _initialized = true;
    } catch (e) {
      // ignore: avoid_print
      print('telemetry_tts.init_failed: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    final t = _tts;
    if (t == null) return;
    try {
      await t.stop();
      await t.speak(text);
      // ignore: avoid_print
      print('telemetry_tts.spoke len=${text.length}');
    } catch (e) {
      // ignore: avoid_print
      print('telemetry_tts.speak_failed: $e');
    }
  }

  Future<void> stop() async {
    final t = _tts;
    if (t == null) return;
    try {
      await t.stop();
    } catch (_) {/* engine pode estar offline */}
  }

  /// Linha curta para falar a cada km. Exemplo:
  /// "1 quilômetro completo. Pace 5 e 30 por quilômetro. Tempo 5 minutos e 30 segundos."
  static String formatKmTelemetry({
    required int kmReached,
    int? kmDurationS,
    double? currentPaceMinKm,
    int? elapsedS,
  }) {
    final parts = <String>['$kmReached quilômetro${kmReached == 1 ? "" : "s"} completo${kmReached == 1 ? "" : "s"}.'];
    if (currentPaceMinKm != null && currentPaceMinKm > 0) {
      final m = currentPaceMinKm.floor();
      final s = ((currentPaceMinKm - m) * 60).round();
      parts.add('Pace $m e ${s.toString().padLeft(2, '0')} por quilômetro.');
    }
    if (kmDurationS != null && kmDurationS > 0) {
      parts.add('Último quilômetro em ${_fmtDuration(kmDurationS)}.');
    } else if (elapsedS != null && elapsedS > 0) {
      parts.add('Tempo total ${_fmtDuration(elapsedS)}.');
    }
    return parts.join(' ');
  }

  static String formatStart(String runType, {bool indoor = false}) {
    if (indoor) return 'Iniciando $runType na esteira. Bom treino.';
    return 'Iniciando $runType. GPS ativo. Bom treino.';
  }

  /// Check-in por tempo (corrida indoor, freemium): sem GPS não há km
  /// pra anunciar — fala tempo decorrido e FC quando disponível.
  static String formatTimeCheckIn({required int elapsedS, int? bpm}) {
    final parts = <String>['${_fmtDuration(elapsedS)} de corrida.'];
    if (bpm != null && bpm > 0) {
      parts.add('Frequência cardíaca $bpm.');
    }
    parts.add('Segue firme.');
    return parts.join(' ');
  }

  static String formatFinish({
    required double distanceM,
    required int elapsedS,
  }) {
    final km = (distanceM / 1000).toStringAsFixed(2);
    return 'Corrida finalizada. Total $km quilômetros em ${_fmtDuration(elapsedS)}. Parabéns.';
  }

  static String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h hora${h == 1 ? "" : "s"} e $m minuto${m == 1 ? "" : "s"}';
    if (m > 0) return '$m minuto${m == 1 ? "" : "s"} e $s segundo${s == 1 ? "" : "s"}';
    return '$s segundo${s == 1 ? "" : "s"}';
  }
}
