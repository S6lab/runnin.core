import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/profile/presentation/pages/health/zones_utils.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

/// De onde vieram restingBpm/maxBpm efetivos.
///   - profile: user preencheu restingBpm + maxBpm explicitamente
///   - derived: caiu na cascata 220-idade ou no biometrics summary observado
///   - genericFallback: nenhum dado real disponível → range placeholder
///     60/190 (vide [_genericRestingBpm]/[_genericMaxBpm]) só pra UI ter
///     algo pra renderizar. Antes desse fallback a página de zonas e o
///     run_detail mostravam banner "sem dados", o que o user reportou
///     como confuso — preferimos mostrar zonas estimadas + badge.
enum BpmRangeSource { profile, derived, genericFallback }

const int _genericRestingBpm = 60;
const int _genericMaxBpm = 190;

class BpmRange {
  final int resting;
  final int max;
  final BpmRangeSource source;
  const BpmRange({required this.resting, required this.max, required this.source});

  /// Sempre verdade no shape novo (resolveBpmRange nunca devolve range
  /// "vazio"). Mantido pra back-compat dos call sites enquanto a
  /// migração rola.
  bool get isValid => max > resting;
}

/// Cascata pros valores efetivos de resting/maxBpm:
///   resting: profile.restingBpm → summary.avgRestingBpm → 60 (genérico)
///   max:     profile.maxBpm → (220 - idade) → summary.maxBpm observado → 190 (genérico)
/// Centralizado pra ser reusado em [HealthZonesPage], detalhe da corrida
/// e estatísticas de histórico — antes a lógica ficava replicada.
BpmRange resolveBpmRange({
  UserProfile? profile,
  BiometricSummary? summary,
}) {
  int? resting = profile?.restingBpm;
  int? max = profile?.maxBpm;
  var source = BpmRangeSource.profile;

  if (resting == null || max == null) {
    source = BpmRangeSource.derived;
    if (max == null) {
      final age = _ageFromBirthDate(profile?.birthDate);
      if (age != null && age > 0 && age < 120) {
        max = 220 - age;
      }
    }
    resting ??= summary?.avgRestingBpm?.round();
    max ??= summary?.maxBpm?.round();
  }

  if (resting == null || max == null || max <= resting) {
    return const BpmRange(
      resting: _genericRestingBpm,
      max: _genericMaxBpm,
      source: BpmRangeSource.genericFallback,
    );
  }

  return BpmRange(resting: resting, max: max, source: source);
}

class RunZoneDistribution {
  /// Lista das 5 zonas (Z1-Z5) com `pctTime` preenchido (0-100). Vazio
  /// quando não dá pra computar zonas (range BPM inválido ou splits sem
  /// avgBpm).
  final List<HealthZone> zones;
  /// BPM máximo registrado na corrida (`run.maxBpm`). Renderizado como
  /// header "FC máx: X bpm" na seção de zonas.
  final int? maxBpmRun;
  /// True quando ao menos 1 split contribuiu pro cálculo (avgBpm > 0
  /// + durationS > 0). False = mostra banner "Sem BPM suficiente".
  final bool hasEnoughBpmData;

  const RunZoneDistribution({
    required this.zones,
    required this.maxBpmRun,
    required this.hasEnoughBpmData,
  });

  factory RunZoneDistribution.empty({int? maxBpmRun}) =>
      RunZoneDistribution(zones: const [], maxBpmRun: maxBpmRun, hasEnoughBpmData: false);
}

/// Calcula a distribuição de tempo por zona cardíaca pra uma run específica.
///
/// Estratégia: para cada `KmSplit` da run, classifica pelo `avgBpm` em
/// uma das 5 zonas (Karvonen via [computeHealthZones]) e soma `durationS`.
/// Percentual final = tempo_zona / tempo_total × 100.
///
/// Splits parciais entram normalmente — sua duração conta proporcionalmente.
/// Splits sem `avgBpm` são ignorados (não temos como classificar).
///
/// Trade-off: usar avgBpm do split (1 valor/km) é aproximação. Pra precisão
/// real teríamos que ler raw points com BPM por segundo (Run.points[].bpm
/// existe mas raramente vem populado). Suficiente pra leitura geral; quem
/// quer detalhamento abre a tela de health/zones.
RunZoneDistribution computeRunZoneDistribution({
  required Run run,
  UserProfile? profile,
  BiometricSummary? summary,
}) {
  final range = resolveBpmRange(profile: profile, summary: summary);
  final zones = computeHealthZones(restingBpm: range.resting, maxBpm: range.max);
  if (zones.isEmpty) {
    return RunZoneDistribution.empty(maxBpmRun: run.maxBpm);
  }

  // Cada slot guarda tempo total nessa zona (em segundos).
  final times = List<int>.filled(zones.length, 0);
  var hasData = false;
  for (final s in run.splits) {
    final bpm = s.avgBpm;
    if (bpm == null || bpm <= 0 || s.durationS <= 0) continue;
    hasData = true;
    // Encontra a zona que cobre esse BPM. Z5 inclui >max (proteção contra
    // sample acima do maxBpm declarado, comum quando profile está stale).
    int idx = zones.length - 1;
    for (var i = 0; i < zones.length; i++) {
      if (bpm < zones[i].maxBpm || i == zones.length - 1) {
        idx = i;
        break;
      }
    }
    times[idx] += s.durationS;
  }

  if (!hasData) {
    return RunZoneDistribution.empty(maxBpmRun: run.maxBpm);
  }

  final total = times.fold<int>(0, (a, b) => a + b);
  if (total == 0) return RunZoneDistribution.empty(maxBpmRun: run.maxBpm);
  // Renderiza zones com `pctTime` preenchido (mesmo widget do health page).
  final filled = <HealthZone>[];
  for (var i = 0; i < zones.length; i++) {
    final z = zones[i];
    final pct = (times[i] / total) * 100;
    filled.add(HealthZone(
      number: z.number,
      label: z.label,
      description: z.description,
      minBpm: z.minBpm,
      maxBpm: z.maxBpm,
      color: z.color,
      pctTime: pct,
    ));
  }
  return RunZoneDistribution(
    zones: filled,
    maxBpmRun: run.maxBpm,
    hasEnoughBpmData: true,
  );
}

/// Versão agregada de [computeRunZoneDistribution] pra um conjunto de runs.
/// Usada na página perfil/saude/zonas pra mostrar a distribuição "longa"
/// do user (últimos N dias), e também onde quer que se queira combinar
/// múltiplas runs num único gráfico de zonas.
///
/// Estratégia idêntica: pra cada run, soma `durationS` por zona via
/// `avgBpm` dos splits (granular) OU do avgBpm da run inteira (fallback
/// pra runs legacy sem splits). Run sem nenhum sinal BPM é ignorada.
RunZoneDistribution computeAggregateRunZoneDistribution({
  required List<Run> runs,
  UserProfile? profile,
  BiometricSummary? summary,
}) {
  final range = resolveBpmRange(profile: profile, summary: summary);
  final zones = computeHealthZones(restingBpm: range.resting, maxBpm: range.max);
  if (zones.isEmpty || runs.isEmpty) {
    return RunZoneDistribution.empty();
  }

  final times = List<int>.filled(zones.length, 0);
  var hasData = false;
  int? observedMax;

  for (final r in runs) {
    if (r.maxBpm != null && r.maxBpm! > 0) {
      observedMax = (observedMax == null || r.maxBpm! > observedMax) ? r.maxBpm : observedMax;
    }
    if (r.splits.isNotEmpty) {
      for (final s in r.splits) {
        final bpm = s.avgBpm;
        if (bpm == null || bpm <= 0 || s.durationS <= 0) continue;
        hasData = true;
        times[_bucketIndexForBpm(bpm, zones)] += s.durationS;
      }
    } else if (r.avgBpm != null && r.avgBpm! > 0 && r.durationS > 0) {
      hasData = true;
      times[_bucketIndexForBpm(r.avgBpm!, zones)] += r.durationS;
    }
  }

  if (!hasData) {
    return RunZoneDistribution.empty(maxBpmRun: observedMax);
  }

  final total = times.fold<int>(0, (a, b) => a + b);
  if (total == 0) return RunZoneDistribution.empty(maxBpmRun: observedMax);

  final filled = <HealthZone>[];
  for (var i = 0; i < zones.length; i++) {
    final z = zones[i];
    filled.add(HealthZone(
      number: z.number,
      label: z.label,
      description: z.description,
      minBpm: z.minBpm,
      maxBpm: z.maxBpm,
      color: z.color,
      pctTime: (times[i] / total) * 100,
    ));
  }
  return RunZoneDistribution(
    zones: filled,
    maxBpmRun: observedMax,
    hasEnoughBpmData: true,
  );
}

int _bucketIndexForBpm(int bpm, List<HealthZone> zones) {
  for (var i = 0; i < zones.length; i++) {
    if (bpm < zones[i].maxBpm || i == zones.length - 1) return i;
  }
  return zones.length - 1;
}

/// Idade em anos a partir de um birthDate ISO (yyyy-MM-dd) ou
/// dd/MM/yyyy. null pra entrada vazia ou inválida.
int? _ageFromBirthDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  DateTime? d;
  try {
    d = DateTime.parse(raw);
  } catch (_) {
    final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
    if (br != null) {
      d = DateTime(
        int.parse(br.group(3)!),
        int.parse(br.group(2)!),
        int.parse(br.group(1)!),
      );
    }
  }
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
    age -= 1;
  }
  return age > 0 ? age : null;
}
