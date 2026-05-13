import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/error_state_widget.dart';

void main() {
  group('ErrorStateWidget', () {
    testWidgets('displays error message', (WidgetTester tester) async {
      const testMessage = 'Test error message';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: ErrorStateWidget(
              message: testMessage,
            ),
          ),
        ),
      );

      expect(find.text(testMessage), findsOneWidget);
    });

    testWidgets('displays retry button when onRetry is provided',
        (WidgetTester tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: Scaffold(
            body: ErrorStateWidget(
              message: 'Error occurred',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);

      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('does not display retry button when onRetry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: ErrorStateWidget(
              message: 'Error occurred',
            ),
          ),
        ),
      );

      expect(find.text('TENTAR NOVAMENTE'), findsNothing);
    });

    testWidgets('displays custom icon when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: ErrorStateWidget(
              message: 'Error occurred',
              icon: Icons.warning,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('renders as fullScreen when fullScreen is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: ErrorStateWidget(
              message: 'Error occurred',
              fullScreen: true,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test for fullScreen mode)
      expect(find.text('Error occurred'), findsOneWidget);
    });
  });
}
