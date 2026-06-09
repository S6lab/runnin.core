import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
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
  /// Número da semana do PLANO em curso (1-based, vem de PlanWeek.weekNumber).
  /// Null quando não há plano ativo. Não confundir com a semana ISO do ano.
  final int? currentPlanWeekNumber;
  /// Resumo biométrico dos últimos 7 dias — alimenta o card SONO em
  /// Status Corporal (avgSleepHours) e fallback do card cardíaco.
  /// Null quando o user não tem wearable conectado ou a chamada falhou.
  final BiometricSummary? biometric;

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
    this.currentPlanWeekNumber,
    this.biometric,
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
  final BiometricRemoteDatasource _biometricDs;

  GetHomeDataUseCase()
    : _userDs = UserRemoteDatasource(),
      _planDs = PlanRemoteDatasource(),
      _runDs = RunRemoteDatasource(),
      _biometricDs = BiometricRemoteDatasource();

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
    // Cada chamada com .catchError individual pra Logger reportar a step
    // exata que falhou (antes o catch em HomeCubit virava genérico "home.load_failed"
    // sem dizer se foi getMe / getCurrentPlan / listRuns).
    final results = await Future.wait([
      _userDs.getMe().catchError((Object e, StackTrace st) {
        Logger.error('home.load.getMe_failed', e, st);
        throw e;
      }),
      // Cache-first: o plano foi recuperado/cacheado no login; invalida só ao
      // gerar novo, aplicar checkpoint/revisão, ou cruzar domingo.
      _planDs.getCurrentPlan(cacheFirst: true).catchError((Object e, StackTrace st) {
        Logger.error('home.load.getCurrentPlan_failed', e, st);
        throw e;
      }),
      _runDs.listRuns(limit: 21).catchError((Object e, StackTrace st) {
        Logger.error('home.load.listRuns_failed', e, st);
        throw e;
      }),
      // Biometric summary 7d — alimenta SONO + fallback cardíaco. Best-effort:
      // se o user não tem wearable conectado, server retorna 200 vazio.
      _biometricDs.getSummary(windowDays: 7).then<BiometricSummary?>((s) => s).catchError(
        (Object e, StackTrace st) {
          Logger.warn('home.load.biometricSummary_failed',
              context: {'err': '$e'});
          return null;
        },
      ),
    ]);

    final profile = results[0] as UserProfile?;
    final plan = results[1] as Plan?;
    final runs = results[2] as List<Run>;
    final biometric = results[3] as BiometricSummary?;
    // Filtra ruído: corridas <30s ou <100m são descartadas dos agregados
    // da home (resumo semanal, atalho "última corrida", weeklyDistanceKm).
    // Espelha o filtro server (get-stats-aggregate / get-stats-breakdown).
    // Mantém consistência: o que /stats já não conta, aqui também não.
    final completedRuns =
        runs
            .where((run) =>
                run.status == 'completed' &&
                run.durationS >= 30 &&
                run.distanceM >= 100)
            .toList()
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
    if (plan != null) {
      final eff = plan.effectiveWeeks;
      if (eff.isNotEmpty) {
        currentPlanWeek = eff[plan.currentWeekIndex(now: today)];
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

      // "Concluída" = a sessão planejada do dia foi executada (server seta
      // executedRunId no complete da run vinculada). Fallback: dia sem sessão
      // mas com corrida registrada (corrida livre) continua marcado como feito.
      final doneOnDay = (session?.isExecuted ?? false) ||
          (session == null &&
              runsThisWeek.any((run) {
                final createdAt = DateTime.tryParse(run.createdAt);
                return createdAt != null && createdAt.weekday == dayOfWeek;
              }));

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
      currentPlanWeekNumber: currentPlanWeek?.weekNumber,
      biometric: biometric,
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
