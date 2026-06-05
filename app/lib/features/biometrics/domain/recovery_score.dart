/// Componentes que entraram no cálculo. Cada flag indica se o sinal estava
/// presente e contribuiu para o score final — UI mostra check/X por sinal
/// pra deixar transparente o que faltava preencher.
class RecoveryComponents {
  final bool sleepUsed;
  final bool restingBpmUsed;
  final bool hrvUsed;

  const RecoveryComponents({
    required this.sleepUsed,
    required this.restingBpmUsed,
    required this.hrvUsed,
  });

  int get signalCount =>
      (sleepUsed ? 1 : 0) + (restingBpmUsed ? 1 : 0) + (hrvUsed ? 1 : 0);
}

class RecoveryScore {
  /// Score 0-100. Null quando temos < 2 sinais (não dá pra estimar com 1 só).
  final int? score;
  final RecoveryComponents components;

  const RecoveryScore({required this.score, required this.components});

  bool get hasScore => score != null;
}

/// Combina BPM resting, horas de sono e HRV num score 0-100 de prontidão.
/// Cada sinal vira um valor [0,1] e os pesos se redistribuem quando algum
/// sinal está ausente — com 3 sinais é 40/35/25 (sono/bpm/hrv); com 2,
/// vira 50/50 entre os presentes; com 0 ou 1, retorna score=null pra UI
/// mostrar banner pedindo conexão de saúde.
///
/// Substitui a fórmula antiga que dependia 100% de HRV — a maioria dos
/// usuários sem Apple Watch ou wearable HRV-capable ficava com 0.
///
/// Normalizações:
/// - Sono: sweet spot 7.5h. score = 1 - |h - 7.5| / 4 (clamped). 6h ≈ 0.62,
///   7.5h = 1.0, 9h ≈ 0.62, 4h ≈ 0.12.
/// - BPM resting: 60bpm = 0.75, 50bpm = 1.0, 80bpm = 0. Formula: (75 - bpm)/20.
/// - HRV: 100ms = 1.0, 0 = 0. Formula: hrv / 100 (clamped).
RecoveryScore computeRecoveryScore({
  num? avgSleepHours,
  num? avgRestingBpm,
  num? avgHrv,
}) {
  final hasSleep = avgSleepHours != null && avgSleepHours > 0;
  final hasBpm = avgRestingBpm != null && avgRestingBpm > 0;
  final hasHrv = avgHrv != null && avgHrv > 0;
  final present = (hasSleep ? 1 : 0) + (hasBpm ? 1 : 0) + (hasHrv ? 1 : 0);

  final components = RecoveryComponents(
    sleepUsed: hasSleep,
    restingBpmUsed: hasBpm,
    hrvUsed: hasHrv,
  );

  if (present < 2) {
    return RecoveryScore(score: null, components: components);
  }

  // Pesos: 3 sinais = 40/35/25; 2 sinais redistribui pra 50/50 entre os
  // presentes (mantém a proporção 40:35 quando sono+bpm sobram → 53/47).
  double wSleep, wBpm, wHrv;
  if (present == 3) {
    wSleep = 0.40;
    wBpm = 0.35;
    wHrv = 0.25;
  } else {
    // Renormaliza só os pesos dos sinais presentes pra somar 1.
    final base = (hasSleep ? 0.40 : 0) + (hasBpm ? 0.35 : 0) + (hasHrv ? 0.25 : 0);
    wSleep = hasSleep ? 0.40 / base : 0;
    wBpm = hasBpm ? 0.35 / base : 0;
    wHrv = hasHrv ? 0.25 / base : 0;
  }

  final pontosSono = hasSleep
      ? (1 - (avgSleepHours - 7.5).abs() / 4).clamp(0.0, 1.0)
      : 0.0;
  final pontosBpm = hasBpm
      ? ((75 - avgRestingBpm) / 20).clamp(0.0, 1.0)
      : 0.0;
  final pontosHrv = hasHrv
      ? (avgHrv / 100).clamp(0.0, 1.0)
      : 0.0;

  final normalized = (pontosSono * wSleep) + (pontosBpm * wBpm) + (pontosHrv * wHrv);
  final score = (normalized * 100).round().clamp(0, 100);
  return RecoveryScore(score: score, components: components);
}
