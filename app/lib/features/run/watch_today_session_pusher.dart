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
    // Fix TF 61: NÃO empurra `session: null` em caso transiente (rede slow,
    // cache miss, exception). Antes qualquer falha em getCurrentPlan
    // empurrava null → Watch limpava UserDefaults → próximo boot do Watch
    // sem sessão. Agora só empurra estado quando temos CERTEZA — ou
    // sessão real, ou rest_day confirmado, ou plano sabidamente ausente.
    try {
      final plan = await _planRemote.getCurrentPlan();
      if (plan == null) {
        // Plano realmente não existe pro user (não onboarded ou ainda gerando).
        // Não limpa o cache do Watch — pode estar transiente. Watch mantém
        // o último estado conhecido até iPhone confirmar com session real.
        return;
      }
      if (!plan.isReady) {
        // Plano em geração — não tem o que mostrar ainda, mas tampouco
        // queremos limpar Watch. Mantém o estado anterior.
        return;
      }
      final today = DateTime.now().weekday; // 1=Mon..7=Sun
      final start = plan.effectiveStartDate;
      final daysFromStart = DateTime.now().difference(start).inDays;
      final weeksRef = plan.effectiveWeeks;
      final weekIdx =
          (daysFromStart / 7).floor().clamp(0, weeksRef.length - 1);
      final week = weeksRef[weekIdx];
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
        // Hoje é REST DAY confirmado (plano carregado, semana checada,
        // sem session pro dayOfWeek). Empurra com flag explícita pro Watch
        // diferenciar de "transiente". Watch limpa apenas neste caso.
        await workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': null,
          'rest_day': true,
        });
      }
    } catch (_) {/* best-effort — não empurra nada em caso de exception */}
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
