import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/router/router_fallback_page.dart';

void main() {
  group('RouterFallbackPage', () {
    testWidgets('renderiza mensagem amigável', (tester) async {
      final router = GoRouter(
        initialLocation: '/x',
        routes: [
          GoRoute(
            path: '/x',
            builder: (_, _) => const RouterFallbackPage(path: '/nao-existe'),
          ),
          GoRoute(path: '/home', builder: (_, _) => const _StubHome()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      // initial frame
      await tester.pump();

      expect(find.text('Tela não encontrada'), findsOneWidget);
      expect(find.text('Voltando pra Home em instantes…'), findsOneWidget);
      expect(find.text('Voltar agora'), findsOneWidget);
    });

    testWidgets('botão "Voltar agora" navega pra /home', (tester) async {
      final router = GoRouter(
        initialLocation: '/x',
        routes: [
          GoRoute(
            path: '/x',
            builder: (_, _) => const RouterFallbackPage(path: '/nao-existe'),
          ),
          GoRoute(path: '/home', builder: (_, _) => const _StubHome()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.text('Voltar agora'));
      await tester.pumpAndSettle();

      expect(find.byType(_StubHome), findsOneWidget);
    });
  });
}

class _StubHome extends StatelessWidget {
  const _StubHome();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}
