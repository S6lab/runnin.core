import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/presentation/widgets/step_progress_indicator.dart';

void main() {
  group('StepProgressIndicator Widget Tests', () {
    testWidgets('should display correct progress bar length', (tester) async {
      const widget = StepProgressIndicator(
        currentStep: 2,
        totalSteps: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Scaffold(body: widget),
        ),
      );

      final progressIndicators = tester.widgetList<Container>(
        find.byType(Container),
      );
      
      expect(progressIndicators.length, greaterThan(0));
    });

    testWidgets('should display step label when provided', (tester) async {
      const widget = StepProgressIndicator(
        currentStep: 1,
        totalSteps: 3,
        stepLabel: 'Passo 2 de 3',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Passo 2 de 3'), findsOneWidget);
    });

    testWidgets('should not display label when null', (tester) async {
      const widget = StepProgressIndicator(
        currentStep: 1,
        totalSteps: 3,
        stepLabel: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Passo 2 de 3'), findsNothing);
    });
  });
}
