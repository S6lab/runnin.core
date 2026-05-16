import 'package:intl/intl.dart';

class WeeklyReport {
  final String weekStart;
  final int sessionsPlanned;
  final int sessionsDone;
  final double totalKm;
  final double plannedKm;
  final String? highlights;
  final String? coachAnalysis;
  final double? averagePace;
  final int totalFreeSessions;
  final double freeKm;
  final String? adaptationSuggestion;

  const WeeklyReport({
    required this.weekStart,
    required this.sessionsPlanned,
    required this.sessionsDone,
    required this.totalKm,
    required this.plannedKm,
    this.highlights,
    this.coachAnalysis,
    this.averagePace,
    this.totalFreeSessions = 0,
    this.freeKm = 0.0,
    this.adaptationSuggestion,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> j) => WeeklyReport(
    weekStart: j['weekStart'] as String,
    sessionsPlanned: j['sessionsPlanned'] as int,
    sessionsDone: j['sessionsDone'] as int,
    totalKm: (j['totalKm'] as num).toDouble(),
    plannedKm: (j['plannedKm'] as num).toDouble(),
    highlights: j['highlights'] as String?,
    coachAnalysis: j['coachAnalysis'] as String?,
    averagePace: j['averagePace'] != null ? (j['averagePace'] as num).toDouble() : null,
    totalFreeSessions: j['totalFreeSessions'] as int? ?? 0,
    freeKm: (j['freeKm'] as num?)?.toDouble() ?? 0.0,
    adaptationSuggestion: j['adaptationSuggestion'] as String?,
  );

  int get adherencePercent {
    if (sessionsPlanned == 0) return 100;
    return ((sessionsDone / sessionsPlanned) * 100).round().clamp(0, 100);
  }

  bool get hasAdherenceWarning => adherencePercent < 70;
  
  String? get dateRange {
    try {
      final startDate = DateTime.parse(weekStart);
      final endDate = startDate.add(const Duration(days: 6));
      final formatter = DateFormat('dd/MM');
      return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
    } catch (_) {
      return null;
    }
  }
}
