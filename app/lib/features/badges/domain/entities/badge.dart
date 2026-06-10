enum BadgeCategory {
  first,
  distanceTotal,
  distanceRun,
  streak,
  pace,
  report,
}

BadgeCategory _categoryFromString(String s) {
  switch (s) {
    case 'first':
      return BadgeCategory.first;
    case 'distance_total':
      return BadgeCategory.distanceTotal;
    case 'distance_run':
      return BadgeCategory.distanceRun;
    case 'streak':
      return BadgeCategory.streak;
    case 'pace':
      return BadgeCategory.pace;
    case 'report':
      return BadgeCategory.report;
  }
  return BadgeCategory.first;
}

class BadgeStatsSnapshot {
  final double? primaryValue;
  final double? distanceKm;
  final int? durationS;
  final String? paceMinKm;
  final String? bestPaceMinKm;
  final int? avgBpm;
  final int? maxBpm;
  final double? weekKm;
  final double? monthKm;
  final double? completionPct;
  final String? periodAvgPace;
  final Map<String, dynamic> extra;

  const BadgeStatsSnapshot({
    this.primaryValue,
    this.distanceKm,
    this.durationS,
    this.paceMinKm,
    this.bestPaceMinKm,
    this.avgBpm,
    this.maxBpm,
    this.weekKm,
    this.monthKm,
    this.completionPct,
    this.periodAvgPace,
    this.extra = const {},
  });

  factory BadgeStatsSnapshot.fromJson(Map<String, dynamic> j) => BadgeStatsSnapshot(
        primaryValue: (j['primaryValue'] as num?)?.toDouble(),
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        durationS: (j['durationS'] as num?)?.toInt(),
        paceMinKm: j['paceMinKm'] as String?,
        bestPaceMinKm: j['bestPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
        maxBpm: (j['maxBpm'] as num?)?.toInt(),
        weekKm: (j['weekKm'] as num?)?.toDouble(),
        monthKm: (j['monthKm'] as num?)?.toDouble(),
        completionPct: (j['completionPct'] as num?)?.toDouble(),
        periodAvgPace: j['periodAvgPace'] as String?,
        extra: (j['extra'] as Map<String, dynamic>?) ?? const {},
      );
}

class Badge {
  final String badgeId;
  final BadgeCategory category;
  final String title;
  final String subtitle;
  final String? description;
  final String? badgeChip;
  final String primaryDisplay;
  final String? primaryUnit;
  final int unlockedAt;
  final String? runId;
  final String? weekStart;
  final String? monthKey;
  final BadgeStatsSnapshot stats;
  final bool seen;
  final int shareCount;

  const Badge({
    required this.badgeId,
    required this.category,
    required this.title,
    required this.subtitle,
    this.description,
    this.badgeChip,
    required this.primaryDisplay,
    this.primaryUnit,
    required this.unlockedAt,
    this.runId,
    this.weekStart,
    this.monthKey,
    required this.stats,
    required this.seen,
    this.shareCount = 0,
  });

  factory Badge.fromJson(Map<String, dynamic> j) {
    final ctx = (j['context'] as Map<String, dynamic>?) ?? const {};
    return Badge(
      badgeId: j['badgeId'] as String,
      category: _categoryFromString(j['category'] as String? ?? 'first'),
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String? ?? '',
      description: j['description'] as String?,
      badgeChip: j['badgeChip'] as String?,
      primaryDisplay: j['primaryDisplay'] as String? ?? '',
      primaryUnit: j['primaryUnit'] as String?,
      unlockedAt: (j['unlockedAt'] as num?)?.toInt() ?? 0,
      runId: ctx['runId'] as String?,
      weekStart: ctx['weekStart'] as String?,
      monthKey: ctx['monthKey'] as String?,
      stats: BadgeStatsSnapshot.fromJson(
        (j['stats'] as Map<String, dynamic>?) ?? const {},
      ),
      seen: j['seen'] == true,
      shareCount: (j['shareCount'] as num?)?.toInt() ?? 0,
    );
  }
}
