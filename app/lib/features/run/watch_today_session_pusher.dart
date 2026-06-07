import 'dart:async';

import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';

/// Empurra a sessão planejada de HOJE pro Watch via WCSession applicationContext
/// quando o iPhone boota. Sem isso, o Watch só vê `today_session` quando o
/// usuário entra em /prep no iPhone — abrindo só o Watch (iPhone na home/
/// outras rotas), TypeSelectorScreen mostra apenas "CORRIDA LIVRE".
///
/// Idempotente: pode ser chamado múltiplas vezes (ex: ao trocar de plano).
/// Best-effort: falha silenciosa se sem rede ou sem plano.
class WatchTodaySessionPusher {
  final PlanRemoteDatasource _planRemote;

  WatchTodaySessionPusher({PlanRemoteDatasource? planRemote})
      : _planRemote = planRemote ?? PlanRemoteDatasource();

  Future<void> pushToday() async {
    try {
      final plan = await _planRemote.getCurrentPlan();
      if (plan == null || !plan.isReady) {
        // Sem plano — limpa o card "Sessão do Dia" se ainda tiver no Watch.
        await workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': null,
        });
        return;
      }
      final today = DateTime.now().weekday; // 1=Mon..7=Sun
      final start = plan.effectiveStartDate;
      final daysFromStart = DateTime.now().difference(start).inDays;
      final weekIdx =
          (daysFromStart / 7).floor().clamp(0, plan.weeks.length - 1);
      final week = plan.weeks[weekIdx];
      final session = week.sessions
          .where((s) => s.dayOfWeek == today)
          .cast<dynamic>()
          .firstWhere((_) => true, orElse: () => null);
      if (session != null) {
        await workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': {
            'type': session.type,
            'distanceKm': session.distanceKm,
            'planSessionId': session.id,
          },
        });
      } else {
        await workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': null,
        });
      }
    } catch (_) {/* best-effort */}
  }

  /// Empurra agora E mais 2 vezes (3s e 8s depois) pra cobrir race window
  /// onde o Watch ainda não tinha terminado de ativar a WCSession quando o
  /// primeiro push aconteceu. iOS Sim em especial demora pra propagar o
  /// applicationContext entre processos — testes mostraram que o primeiro
  /// push logo após boot é frequentemente dropado mesmo com reachable=1.
  /// Idempotente — updateApplicationContext faz dedup.
  void pushTodayWithRetries() {
    unawaited(pushToday());
    Timer(const Duration(seconds: 3), () => unawaited(pushToday()));
    Timer(const Duration(seconds: 8), () => unawaited(pushToday()));
  }
}

final watchTodaySessionPusher = WatchTodaySessionPusher();
