import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/presentation/widgets/step_progress_indicator.dart';

void main() {
  group('StepProgressIndicator', () {
    testWidgets('renders progress indicator with correct number of steps',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepProgressIndicator(
            currentStep: 0,
            totalSteps: 5,
          ),
        ),
      );

      final indicatorFinder = find.byType(StepProgressIndicator);
      expect(indicatorFinder, findsOneWidget);

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsNWidgets(5));
    });

    testWidgets('displays step label when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepProgressIndicator(
            currentStep: 1,
            totalSteps: 3,
            stepLabel: 'Step 2 of 3',
          ),
        ),
      );

      final textFinder = find.text('Step 2 of 3');
      expect(textFinder, findsOneWidget);
    });
  });
}
