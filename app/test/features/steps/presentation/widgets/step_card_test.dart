import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/steps/domain/entities/step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/presentation/widgets/step_card.dart';

void main() {
  late AppStep testStep;

  setUp(() {
    testStep = const AppStep(
      id: 'step-1',
      title: 'Test Step',
      description: 'Step Description',
      content: SizedBox.shrink(),
    );
  });

  testWidgets('renders step card with active state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: StepCard(
              step: testStep,
              isActive: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(StepCard), findsOneWidget);
    expect(find.text('TEST STEP'), findsOneWidget);
  });

  testWidgets('renders step card with completed status', (WidgetTester tester) async {
    final completedStep = testStep.copyWith(status: StepStatus.completed);
    
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: StepCard(
              step: completedStep,
              isActive: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('renders step card with error status', (WidgetTester tester) async {
    final errorStep = testStep.copyWith(status: StepStatus.error);
    
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: StepCard(
              step: errorStep,
              isActive: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('shows validation errors when provided', (WidgetTester tester) async {
    final rule = StepValidationRule(
      field: 'test_field',
      message: 'Invalid data',
      validate: (_) => false,
    );
    
    final errorStep = testStep.copyWith(
      data: {'test_field': 'invalid'},
    );
    
    final validationErrors = [rule.validateStep(errorStep)!];
    
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: StepCard(
              step: errorStep,
              isActive: true,
              validationErrors: validationErrors,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invalid data'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (WidgetTester tester) async {
    bool tapped = false;
    
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: StepCard(
              step: testStep,
              isActive: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );
    
    await tester.tap(find.text('TEST STEP'));
    await tester.pumpAndSettle();

    expect(tapped, true);
  });
}
