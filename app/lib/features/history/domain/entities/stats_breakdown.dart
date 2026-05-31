/// Espelha o payload de `GET /v1/stats/breakdown?period=` (servidor).
/// Stats consolidados do período + séries planejado-vs-realizado pra
/// os gráficos de volume e pace da aba DADOS.
class BreakdownStats {
  final int runs;
  final double totalDistanceKm;
  final double avgDistanceKm;
  final int totalDurationS;
  final String? avgPace; // "M:SS"
  final int calories;
  final int level; // 1-based, lifetime
  final String levelName; // lifetime
  final int? avgBpm;
  final int? maxBpm;
  final int streak; // lifetime
  final int totalXp; // do período

  const BreakdownStats({
    required this.runs,
    required this.totalDistanceKm,
    required this.avgDistanceKm,
    required this.totalDurationS,
    required this.avgPace,
    required this.calories,
    required this.level,
    required this.levelName,
    required this.avgBpm,
    required this.maxBpm,
    required this.streak,
    required this.totalXp,
  });

  factory BreakdownStats.fromJson(Map<String, dynamic> j) => BreakdownStats(
        runs: (j['runs'] as num?)?.toInt() ?? 0,
        totalDistanceKm: (j['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        avgDistanceKm: (j['avgDistanceKm'] as num?)?.toDouble() ?? 0,
        totalDurationS: (j['totalDurationS'] as num?)?.toInt() ?? 0,
        avgPace: j['avgPace'] as String?,
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        levelName: j['levelName'] as String? ?? '',
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
        maxBpm: (j['maxBpm'] as num?)?.toInt(),
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
      );

  /// Tempo total formatado (ex: "3h20m" ou "45m").
  String get totalTimeLabel {
    final totalMin = totalDurationS ~/ 60;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';
  }
}

class VolumeBucket {
  final String label;
  final double plannedKm;
  final double realizedKm;
  const VolumeBucket({
    required this.label,
    required this.plannedKm,
    required this.realizedKm,
  });

  factory VolumeBucket.fromJson(Map<String, dynamic> j) => VolumeBucket(
        label: j['label'] as String? ?? '',
        plannedKm: (j['plannedKm'] as num?)?.toDouble() ?? 0,
        realizedKm: (j['realizedKm'] as num?)?.toDouble() ?? 0,
      );
}

class PaceBucket {
  final String label;
  final int? projectedPaceSec;
  final int? avgPaceSec;
  const PaceBucket({
    required this.label,
    required this.projectedPaceSec,
    required this.avgPaceSec,
  });

  factory PaceBucket.fromJson(Map<String, dynamic> j) => PaceBucket(
        label: j['label'] as String? ?? '',
        projectedPaceSec: (j['projectedPaceSec'] as num?)?.toInt(),
        avgPaceSec: (j['avgPaceSec'] as num?)?.toInt(),
      );
}

class StatsBreakdown {
  final String period;
  final BreakdownStats stats;
  final List<VolumeBucket> volume;
  final List<PaceBucket> pace;

  const StatsBreakdown({
    required this.period,
    required this.stats,
    required this.volume,
    required this.pace,
  });

  factory StatsBreakdown.fromJson(Map<String, dynamic> j) => StatsBreakdown(
        period: j['period'] as String? ?? '',
        stats: BreakdownStats.fromJson(j['stats'] as Map<String, dynamic>),
        volume: ((j['volume'] as List?) ?? [])
            .map((e) => VolumeBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
        pace: ((j['pace'] as List?) ?? [])
            .map((e) => PaceBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
