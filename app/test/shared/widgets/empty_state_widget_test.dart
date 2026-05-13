import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('displays icon and title', (WidgetTester tester) async {
      const testTitle = 'No items found';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: testTitle,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('displays subtitle when provided',
        (WidgetTester tester) async {
      const testSubtitle = 'Try adding some items';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No items',
              subtitle: testSubtitle,
            ),
          ),
        ),
      );

      expect(find.text(testSubtitle), findsOneWidget);
    });

    testWidgets('displays action button when provided',
        (WidgetTester tester) async {
      var actionCalled = false;
      const testActionLabel = 'Add Item';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No items',
              actionLabel: testActionLabel,
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.text(testActionLabel), findsOneWidget);

      await tester.tap(find.text(testActionLabel));
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });

    testWidgets('does not display action button when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No items',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders as fullScreen by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No items',
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test)
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('renders inline when fullScreen is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No items',
              fullScreen: false,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test for inline mode)
      expect(find.text('No items'), findsOneWidget);
    });
  });
}
