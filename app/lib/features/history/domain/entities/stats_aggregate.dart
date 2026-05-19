class StatsTotals {
  final int count;
  final num totalDistanceM;
  final int totalDurationS;
  final int totalCalories;
  final int totalXp;

  const StatsTotals({
    required this.count,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.totalCalories,
    required this.totalXp,
  });

  factory StatsTotals.fromJson(Map<String, dynamic> j) => StatsTotals(
        count: (j['count'] as num?)?.toInt() ?? 0,
        totalDistanceM: (j['totalDistanceM'] as num?) ?? 0,
        totalDurationS: (j['totalDurationS'] as num?)?.toInt() ?? 0,
        totalCalories: (j['totalCalories'] as num?)?.toInt() ?? 0,
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
      );
}

class StatsAverages {
  final String? avgPaceMinKm;
  final int? avgBpm;
  final int? maxBpm;
  final num avgDistanceKmPerRun;

  const StatsAverages({
    this.avgPaceMinKm,
    this.avgBpm,
    this.maxBpm,
    required this.avgDistanceKmPerRun,
  });

  factory StatsAverages.fromJson(Map<String, dynamic> j) => StatsAverages(
        avgPaceMinKm: j['avgPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
        maxBpm: (j['maxBpm'] as num?)?.toInt(),
        avgDistanceKmPerRun: (j['avgDistanceKmPerRun'] as num?) ?? 0,
      );
}

class StatsDeltas {
  final int? pacePctVsPrev;
  final int? volumePctVsPrev;
  final int? bpmDeltaBpm;
  final int runsCountDelta;

  const StatsDeltas({
    this.pacePctVsPrev,
    this.volumePctVsPrev,
    this.bpmDeltaBpm,
    required this.runsCountDelta,
  });

  factory StatsDeltas.fromJson(Map<String, dynamic> j) => StatsDeltas(
        pacePctVsPrev: (j['pacePctVsPrev'] as num?)?.toInt(),
        volumePctVsPrev: (j['volumePctVsPrev'] as num?)?.toInt(),
        bpmDeltaBpm: (j['bpmDeltaBpm'] as num?)?.toInt(),
        runsCountDelta: (j['runsCountDelta'] as num?)?.toInt() ?? 0,
      );
}

class WeeklyVolumeEntry {
  final String weekLabel;
  final num plannedKm;
  final num executedKm;

  const WeeklyVolumeEntry({
    required this.weekLabel,
    required this.plannedKm,
    required this.executedKm,
  });

  factory WeeklyVolumeEntry.fromJson(Map<String, dynamic> j) => WeeklyVolumeEntry(
        weekLabel: j['weekLabel'] as String? ?? '',
        plannedKm: (j['plannedKm'] as num?) ?? 0,
        executedKm: (j['executedKm'] as num?) ?? 0,
      );
}

class StatsTrendEntry {
  final String date;
  final String? avgPaceMinKm;
  final int? avgBpm;

  const StatsTrendEntry({
    required this.date,
    this.avgPaceMinKm,
    this.avgBpm,
  });

  factory StatsTrendEntry.fromJson(Map<String, dynamic> j) => StatsTrendEntry(
        date: j['date'] as String? ?? '',
        avgPaceMinKm: j['avgPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
      );
}

class StatsAggregate {
  final StatsTotals totals;
  final StatsAverages averages;
  final StatsDeltas deltas;
  final List<double> zoneDistribution;
  final List<WeeklyVolumeEntry> weeklyVolume;
  final List<StatsTrendEntry> paceTrend;
  final List<StatsTrendEntry> bpmTrend;

  const StatsAggregate({
    required this.totals,
    required this.averages,
    required this.deltas,
    required this.zoneDistribution,
    required this.weeklyVolume,
    required this.paceTrend,
    required this.bpmTrend,
  });

  factory StatsAggregate.fromJson(Map<String, dynamic> j) => StatsAggregate(
        totals: StatsTotals.fromJson(j['totals'] as Map<String, dynamic>? ?? {}),
        averages: StatsAverages.fromJson(j['averages'] as Map<String, dynamic>? ?? {}),
        deltas: StatsDeltas.fromJson(j['deltas'] as Map<String, dynamic>? ?? {}),
        zoneDistribution: (j['zoneDistribution'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
        weeklyVolume: (j['weeklyVolume'] as List<dynamic>? ?? [])
            .map((e) => WeeklyVolumeEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        paceTrend: (j['paceTrend'] as List<dynamic>? ?? [])
            .map((e) => StatsTrendEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        bpmTrend: (j['bpmTrend'] as List<dynamic>? ?? [])
            .map((e) => StatsTrendEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
