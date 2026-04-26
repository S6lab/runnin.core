import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

class HomeData {
  final UserProfile? profile;
  final Plan? plan;
  final PlanSession? todaySession;
  final List<WeekDayData> weekDays;
  final Run? latestRun;
  final List<Run> completedRuns;
  final double weeklyDistanceKm;
  final int completedSessions;
  final int plannedSessions;
  final int streakDays;

  const HomeData({
    required this.profile,
    required this.plan,
    required this.todaySession,
    required this.weekDays,
    required this.latestRun,
    required this.completedRuns,
    required this.weeklyDistanceKm,
    required this.completedSessions,
    required this.plannedSessions,
    required this.streakDays,
  });
}

class WeekDayData {
  final int dayOfWeek;
  final String shortName;
  final PlanSession? session;
  final bool isToday;
  final bool isDone;

  const WeekDayData({
    required this.dayOfWeek,
    required this.shortName,
    this.session,
    required this.isToday,
    required this.isDone,
  });
}

class GetHomeDataUseCase {
  final UserRemoteDatasource _userDs;
  final PlanRemoteDatasource _planDs;
  final RunRemoteDatasource _runDs;

  GetHomeDataUseCase()
    : _userDs = UserRemoteDatasource(),
      _planDs = PlanRemoteDatasource(),
      _runDs = RunRemoteDatasource();

  static const _dayNames = [
    '',
    'SEG',
    'TER',
    'QUA',
    'QUI',
    'SEX',
    'SAB',
    'DOM',
  ];

  Future<HomeData> execute() async {
    final results = await Future.wait([
      _userDs.getMe(),
      _planDs.getCurrentPlan(),
      _runDs.listRuns(limit: 21),
    ]);

    final profile = results[0] as UserProfile?;
    final plan = results[1] as Plan?;
    final runs = results[2] as List<Run>;
    final completedRuns =
        runs.where((run) => run.status == 'completed').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final today = DateTime.now();
    final todayWeekday = today.weekday;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final mondayMidnight = DateTime(monday.year, monday.month, monday.day);

    final runsThisWeek = completedRuns.where((run) {
      final createdAt = DateTime.tryParse(run.createdAt);
      if (createdAt == null) return false;
      return !createdAt.isBefore(mondayMidnight);
    }).toList();

    PlanWeek? currentPlanWeek;
    if (plan != null && plan.weeks.isNotEmpty) {
      final created = DateTime.tryParse(plan.createdAt);
      if (created != null) {
        final daysSinceCreation = today.difference(created).inDays;
        final weekIndex = (daysSinceCreation / 7).floor().clamp(
          0,
          plan.weeks.length - 1,
        );
        currentPlanWeek = plan.weeks[weekIndex];
      } else {
        currentPlanWeek = plan.weeks.first;
      }
    }

    PlanSession? todaySession;
    if (currentPlanWeek != null) {
      for (final session in currentPlanWeek.sessions) {
        if (session.dayOfWeek == todayWeekday) {
          todaySession = session;
          break;
        }
      }
    }

    final weekDays = List.generate(7, (index) {
      final dayOfWeek = index + 1;
      PlanSession? session;
      if (currentPlanWeek != null) {
        for (final item in currentPlanWeek.sessions) {
          if (item.dayOfWeek == dayOfWeek) {
            session = item;
            break;
          }
        }
      }

      final doneOnDay = runsThisWeek.any((run) {
        final createdAt = DateTime.tryParse(run.createdAt);
        return createdAt != null && createdAt.weekday == dayOfWeek;
      });

      return WeekDayData(
        dayOfWeek: dayOfWeek,
        shortName: _dayNames[dayOfWeek],
        session: session,
        isToday: dayOfWeek == todayWeekday,
        isDone: doneOnDay,
      );
    });

    final weeklyDistanceKm = runsThisWeek.fold<double>(
      0,
      (sum, run) => sum + (run.distanceM / 1000),
    );
    final plannedSessions = currentPlanWeek?.sessions.length ?? 0;
    final completedSessions = weekDays.where((day) => day.isDone).length;

    return HomeData(
      profile: profile,
      plan: plan,
      todaySession: todaySession,
      weekDays: weekDays,
      latestRun: completedRuns.isEmpty ? null : completedRuns.first,
      completedRuns: completedRuns,
      weeklyDistanceKm: weeklyDistanceKm,
      completedSessions: completedSessions,
      plannedSessions: plannedSessions,
      streakDays: _calculateStreakDays(completedRuns),
    );
  }

  int _calculateStreakDays(List<Run> runs) {
    if (runs.isEmpty) return 0;

    final uniqueDays = <DateTime>{};
    for (final run in runs) {
      final createdAt = DateTime.tryParse(run.createdAt);
      if (createdAt == null) continue;
      uniqueDays.add(DateTime(createdAt.year, createdAt.month, createdAt.day));
    }

    final orderedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    if (!uniqueDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    for (final day in orderedDays) {
      final normalized = DateTime(day.year, day.month, day.day);
      if (normalized == cursor) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (normalized.isBefore(cursor)) {
        break;
      }
    }

    return streak;
  }
}
