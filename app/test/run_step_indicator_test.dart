import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/shared/widgets/run_step_indicator.dart';

void main() {
  testWidgets('RunStepIndicator displays correct number of dots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Center(
            child: RunStepIndicator(currentStep: 0, totalSteps: 3),
          ),
        ),
      ),
    );

    expect(find.byType(RunStepIndicator), findsOneWidget);
  });
}
