import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/loading_widget.dart';

void main() {
  group('LoadingWidget', () {
    testWidgets('displays circular progress indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays message when provided',
        (WidgetTester tester) async {
      const testMessage = 'Loading data...';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(
              message: testMessage,
            ),
          ),
        ),
      );

      expect(find.text(testMessage), findsOneWidget);
    });

    testWidgets('does not display message when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(),
          ),
        ),
      );

      // Should only find the progress indicator, no text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders as fullScreen when fullScreen is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(
              fullScreen: true,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test for fullScreen mode)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with panel when usePanel is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(
              usePanel: true,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test for panel mode)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders without panel when usePanel is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(
              usePanel: false,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test for no panel mode)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('respects custom height when provided',
        (WidgetTester tester) async {
      const customHeight = 200.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppPalette.lightPalette,
          home: const Scaffold(
            body: LoadingWidget(
              usePanel: true,
              height: customHeight,
            ),
          ),
        ),
      );

      // Verify the widget renders (basic smoke test with custom height)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Find the SizedBox with the custom height
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(LoadingWidget),
          matching: find.byType(SizedBox),
        ).first,
      );

      expect(sizedBox.height, equals(customHeight));
    });
  });
}
