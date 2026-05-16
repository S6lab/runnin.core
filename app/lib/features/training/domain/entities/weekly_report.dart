class WeeklyReport {
  final String weekStart;
  final int sessionsPlanned;
  final int sessionsDone;
  final double totalKm;
  final double plannedKm;
  final String? highlights;
  final String? coachAnalysis;

  const WeeklyReport({
    required this.weekStart,
    required this.sessionsPlanned,
    required this.sessionsDone,
    required this.totalKm,
    required this.plannedKm,
    this.highlights,
    this.coachAnalysis,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> j) => WeeklyReport(
    weekStart: j['weekStart'] as String,
    sessionsPlanned: j['sessionsPlanned'] as int,
    sessionsDone: j['sessionsDone'] as int,
    totalKm: (j['totalKm'] as num).toDouble(),
    plannedKm: (j['plannedKm'] as num).toDouble(),
    highlights: j['highlights'] as String?,
    coachAnalysis: j['coachAnalysis'] as String?,
  );

  int get adherencePercent {
    if (sessionsPlanned == 0) return 100;
    return ((sessionsDone / sessionsPlanned) * 100).round().clamp(0, 100);
  }
}
