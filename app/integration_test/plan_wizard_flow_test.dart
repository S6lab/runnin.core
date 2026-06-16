/// Integration test: jornada do wizard de plano (RACE) até o PRÉ-submit.
///
/// Valida no simulador o que widget tests não cobrem: a sequência real de
/// steps da jornada V4, a raceDate DERIVADA (início+janela+dia) e o botão
/// final habilitado — sem disparar o POST /plans/generate (sem conta).
///
/// Rodar: cd app && flutter test integration_test/plan_wizard_flow_test.dart -d SIM_ID
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:runnin/features/subscriptions/domain/subscription_plan.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/presentation/pages/plan_setup_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // apiClient injeta FirebaseAuth token nas requests do wizard (stats,
    // profile, config) — precisa do app Firebase inicializado mesmo sem
    // login (as chamadas falham com catch silencioso, que é o esperado).
    await Firebase.initializeApp();
    // Gate premium do wizard: atravessa sem rede.
    subscriptionController.debugOverrideSubscription(
      const UserSubscription(
        planId: 'pro',
        plan: SubscriptionPlan(
          id: 'pro',
          name: 'Pro (teste)',
          priceLabel: '',
          periodLabel: '',
          features: PlanFeatures(
            runTracking: true,
            freeRun: true,
            plannedRun: true,
            generatePlan: true,
          ),
          limits: PlanLimits(),
        ),
      ),
    );
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) => tapText(tester, 'CONTINUAR /');

  testWidgets('jornada race completa até o pré-submit com data derivada', (tester) async {
    final router = GoRouter(
      initialLocation: '/training/criar-plano',
      routes: [
        GoRoute(path: '/training/criar-plano', builder: (_, _) => const PlanSetupPage()),
        GoRoute(path: '/onboarding', builder: (_, _) => const Scaffold(body: Text('onboarding'))),
        GoRoute(path: '/assessment-run', builder: (_, _) => const Scaffold(body: Text('assessment'))),
        GoRoute(path: '/paywall', builder: (_, _) => const Scaffold(body: Text('paywall'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 0. Oferta de avaliação (flag ligada) — segue manual.
    expect(find.textContaining('avaliação'), findsWidgets);
    await next(tester);

    // 1. Intro.
    await next(tester);

    // 2. goalKind = RACE.
    await tapText(tester, 'ATINGIR UMA META');
    await next(tester);

    // 3. Nível.
    await tapText(tester, 'INICIANTE COM REGULARIDADE');
    await next(tester);

    // 4. Capacidade (manual): JÁ CORRO + 5K em 30:00 + 22 km/sem.
    await tapText(tester, 'JÁ CORRO');
    await tapText(tester, '5K');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '30');
    await tester.enterText(fields.at(1), '00');
    await tester.enterText(fields.at(2), '22');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await next(tester);

    // 5. Distância da prova: 10K + COMPLETAR.
    await tapText(tester, '10K');
    await tapText(tester, 'COMPLETAR');
    await next(tester);

    // 6. Dias e frequência: defaults (4x, seg/qua/sex/sáb) já são válidos.
    await next(tester);

    // 7. Timing: HOJE já selecionado; escolhe janela FACTÍVEL → o dia
    //    default (domingo) deriva a raceDate e o resumo "PROVA:" aparece.
    await tapText(tester, 'FACTÍVEL');
    expect(find.textContaining('PROVA:'), findsOneWidget,
        reason: 'raceDate derivada de início+janela+dia deve aparecer no resumo');
    await next(tester);

    // 8. Rotina.
    await tapText(tester, 'MANHÃ');
    await tapText(tester, '06:00');
    await tapText(tester, '22:00');

    // 9. Botão final do wizard pronto pro submit — NÃO tocamos (sem conta).
    expect(find.text('CRIAR PLANO /'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('CRIAR PLANO /'), matching: find.byType(ElevatedButton)),
    );
    expect(btn.onPressed, isNotNull, reason: 'jornada completa deve habilitar o CRIAR PLANO');
  });
}
