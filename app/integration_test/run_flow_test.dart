/// Integration test: fluxo de corrida (Free Run) com GPS simulado.
///
/// Valida no simulador o caminho start → telemetria → split de km →
/// finish → /report, usando o MockGpsService real (mesmo code path do
/// RunBloc em produção) e um RunRemoteDatasource fake — sem rede/conta.
///
/// Pré-requisito (uma vez por simulador): permissão de localização, senão
/// o _onStart trava no dialog nativo:
///   xcrun simctl privacy SIM_ID grant location-always com.s6lab.runnin
/// Rodar: cd app && flutter test integration_test/run_flow_test.dart -d SIM_ID
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:runnin/core/debug/mock_gps_service.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/pages/active_run_page.dart';
import 'package:runnin/features/run/presentation/pages/report_page.dart';
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';

/// Substitui a API de runs: cria/completa em memória. unlockedBadges fica
/// vazio (caminho direto pro /report, sem BadgePopupModal).
class _FakeRunRemote implements RunRemoteDatasource {
  Run? completed;
  List<KmSplit>? splitsSentOnComplete;

  Run _build(String id, {String status = 'active', double distanceM = 0, int durationS = 0}) =>
      Run(
        id: id,
        status: status,
        type: 'Free Run',
        distanceM: distanceM,
        durationS: durationS,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

  @override
  Future<Run> createRun({
    required String type,
    String? targetPace,
    String? targetDistance,
    String? planSessionId,
    String? environment,
    double? assessmentTargetKm,
  }) async => _build('it-run-1');

  @override
  Future<void> addGpsBatch(String runId, List<GpsPoint> points) async {}

  @override
  Future<Run> completeRun(
    String runId, {
    required double distanceM,
    required int durationS,
    int? avgBpm,
    int? maxBpm,
    List<KmSplit>? splits,
    List<Map<String, dynamic>>? telemetryTimeline,
  }) async {
    splitsSentOnComplete = splits;
    completed = _build(runId, status: 'completed', distanceM: distanceM, durationS: durationS);
    return completed!;
  }

  @override
  Future<Run> submitFeedback(String runId, List<CheckpointInput> inputs) async =>
      completed ?? _build(runId, status: 'completed');

  @override
  Future<Run> getRun(String runId) async => completed ?? _build(runId);

  @override
  Future<List<GpsPoint>> getGpsPoints(String runId) async => const [];

  @override
  Future<List<Run>> listRuns({int limit = 20}) async => const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // apiClient (interceptor FirebaseAuth) é tocado por datasources
    // secundários do bloc (profile, plano) — falham com catch, mas o
    // app Firebase precisa existir.
    await Firebase.initializeApp();
  });

  /// pump em tempo real até a condição (live binding: a Duration espera
  /// de verdade). pumpAndSettle não serve — a corrida tem timers 1Hz.
  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() cond, {
    required Duration timeout,
    required String Function() reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timeout: ${reason()}');
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets(
    'free run com GPS mock: start → 1km → finish → report',
    (tester) async {
      // Mesmo mock usado no debug manual: 2:30/km (6,67 m/s) fica abaixo
      // do teto de implied speed do filtro anti-drift (8 m/s) e fecha
      // 1km em ~2,5min de teste.
      mockGpsService.enabled = true;
      mockGpsService.paceMinKm = 2.5;

      final fake = _FakeRunRemote();
      final router = GoRouter(
        initialLocation: '/run',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                BlocProvider(create: (_) => RunBloc(remote: fake), child: child),
            routes: [
              GoRoute(
                path: '/run',
                // autoStart = caminho real do Watch: dispara StartRun no
                // primeiro frame, sem o botão de fones/INICIAR.
                builder: (_, _) => const ActiveRunPage(
                  initialType: 'Free Run',
                  isPremium: false,
                  autoStart: true,
                ),
              ),
              GoRoute(
                path: '/report',
                builder: (_, state) => ReportPage(runId: state.extra as String? ?? ''),
              ),
            ],
          ),
          GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home'))),
          GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('login'))),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(seconds: 1));

      final bloc = BlocProvider.of<RunBloc>(tester.element(find.byType(ActiveRunPage)));

      // 1. StartRun (autoStart) cria a run no fake e abre o stream mock.
      await waitUntil(tester, () => bloc.state.status == RunStatus.active,
          timeout: const Duration(seconds: 30),
          reason: () => 'corrida deve ficar ativa '
              '(status=${bloc.state.status} error=${bloc.state.error})');
      expect(bloc.state.runId, 'it-run-1');

      // 2. Telemetria avança: distância cresce até passar de 1km (split
      //    completo + km_reached do TTS freemium no caminho).
      await waitUntil(tester, () => bloc.state.distanceM >= 1050,
          timeout: const Duration(minutes: 4),
          reason: () => 'GPS mock deve acumular >1km '
              '(distanceM=${bloc.state.distanceM} pts=${bloc.state.points.length})');
      expect(bloc.state.elapsedS, greaterThan(0));
      expect(bloc.state.points.length, greaterThan(30));

      // 3. FINALIZAR → CompleteRun → fake responde → status completed.
      await tester.tap(find.textContaining('FINALIZAR').first, warnIfMissed: false);
      await waitUntil(tester, () => bloc.state.status == RunStatus.completed,
          timeout: const Duration(seconds: 30),
          reason: () => 'finish deve completar via fake '
              '(status=${bloc.state.status} error=${bloc.state.error})');

      // Splits enviados no complete têm o 1º km fechado (kmIndex 0-based).
      final splits = fake.splitsSentOnComplete ?? const [];
      expect(splits, isNotEmpty, reason: 'finish deve enviar splits');
      expect(splits.first.kmIndex, 0);
      expect(splits.first.isPartial, isFalse, reason: '1º km deve estar completo');

      // 4. BlocListener navega pro /report, que renderiza o cabeçalho.
      await waitUntil(tester, () => find.text('CORRIDA CONCLUÍDA').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
          reason: () => '/report deve renderizar');
      expect(find.text('RELATÓRIO'), findsOneWidget);

      mockGpsService.enabled = false;
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
