class WeeklyDistance {
  final DateTime weekStart;
  final double distanceKm;

  const WeeklyDistance({required this.weekStart, required this.distanceKm});
}

class DashboardStats {
  final int totalRuns;
  final double totalDistanceKm;
  final int totalDurationS;
  final String? avgPace;
  final int streakDays;
  final int totalXp;
  final int level;
  final int planWeeksCompleted;
  final int planWeeksTotal;
  final List<WeeklyDistance> weeklyDistances;

  const DashboardStats({
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.totalDurationS,
    this.avgPace,
    required this.streakDays,
    required this.totalXp,
    required this.level,
    required this.planWeeksCompleted,
    required this.planWeeksTotal,
    required this.weeklyDistances,
  });
}
