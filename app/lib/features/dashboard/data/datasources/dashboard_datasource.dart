import 'package:runnin/features/dashboard/domain/dashboard_stats.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

class DashboardDatasource {
  final RunRemoteDatasource _runDs;
  final PlanRemoteDatasource _planDs;

  DashboardDatasource()
      : _runDs = RunRemoteDatasource(),
        _planDs = PlanRemoteDatasource();

  Future<DashboardStats> load() async {
    final results = await Future.wait([
      _runDs.listRuns(limit: 200),
      _planDs.getCurrentPlan(),
    ]);

    final runs = results[0] as List<Run>;
    final plan = results[1] as Plan?;

    final completed = runs.where((r) => r.status == 'completed').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalRuns = completed.length;
    final totalDistanceKm = completed.fold(0.0, (s, r) => s + r.distanceM) / 1000;
    final totalDurationS = completed.fold(0, (s, r) => s + r.durationS);
    final totalXp = completed.fold(0, (s, r) => s + (r.xpEarned ?? 0));
    final level = (totalXp / 500).floor() + 1;

    // Pace médio geral
    String? avgPace;
    if (totalDistanceKm > 0 && totalDurationS > 0) {
      final paceSecPerKm = totalDurationS / totalDistanceKm;
      final paceMin = (paceSecPerKm / 60).floor();
      final paceSec = (paceSecPerKm % 60).round();
      avgPace = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    }

    // Streak
    final streakDays = _calculateStreak(completed);

    // Distâncias semanais (últimas 6 semanas)
    final weeklyDistances = _buildWeeklyChart(completed, 6);

    // Progresso no plano
    int planWeeksCompleted = 0;
    int planWeeksTotal = 0;
    if (plan != null && plan.isReady) {
      planWeeksTotal = plan.weeks.length;
      final created = DateTime.tryParse(plan.createdAt);
      if (created != null) {
        final daysSince = DateTime.now().difference(created).inDays;
        planWeeksCompleted = (daysSince / 7).floor().clamp(0, planWeeksTotal);
      }
    }

    return DashboardStats(
      totalRuns: totalRuns,
      totalDistanceKm: totalDistanceKm,
      totalDurationS: totalDurationS,
      avgPace: avgPace,
      streakDays: streakDays,
      totalXp: totalXp,
      level: level,
      planWeeksCompleted: planWeeksCompleted,
      planWeeksTotal: planWeeksTotal,
      weeklyDistances: weeklyDistances,
    );
  }

  int _calculateStreak(List<Run> sortedRuns) {
    if (sortedRuns.isEmpty) return 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    int streak = 0;
    var checkDate = todayDate;

    while (true) {
      final hasRun = sortedRuns.any((r) {
        final d = DateTime.tryParse(r.createdAt);
        if (d == null) return false;
        final date = DateTime(d.year, d.month, d.day);
        return date == checkDate;
      });
      if (!hasRun) break;
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<WeeklyDistance> _buildWeeklyChart(List<Run> sortedRuns, int weeks) {
    final today = DateTime.now();
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final result = <WeeklyDistance>[];

    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = DateTime(
        mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day,
      ).subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final distM = sortedRuns
          .where((r) {
            final d = DateTime.tryParse(r.createdAt);
            if (d == null) return false;
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          })
          .fold(0.0, (s, r) => s + r.distanceM);

      result.add(WeeklyDistance(weekStart: weekStart, distanceKm: distM / 1000));
    }
    return result;
  }
}
