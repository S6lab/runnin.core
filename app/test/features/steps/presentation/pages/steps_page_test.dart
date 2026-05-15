import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runnin/features/steps/domain/entities/step.dart';
import 'package:runnin/features/steps/presentation/bloc/step_bloc.dart';
import 'package:runnin/features/steps/presentation/pages/steps_page.dart';
import 'package:runnin/features/steps/presentation/widgets/step_card.dart';
import 'package:runnin/features/steps/presentation/widgets/step_navigation_buttons.dart';

void main() {
  group('StepsPage', () {
    late List<AppStep> steps;

    setUp(() {
      steps = [
        AppStep(
          id: '1',
          title: 'Step 1',
          content: Container(),
        ),
        AppStep(
          id: '2',
          title: 'Step 2',
          content: Container(),
        ),
        AppStep(
          id: '3',
          title: 'Step 3',
          content: Container(),
          isLastStep: true,
        ),
      ];
    });

    testWidgets('should display correct step title', (WidgetTester tester) async {
      final bloc = StepBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: BlocProvider<StepBloc>.value(
              value: bloc,
              child: StepsPage(
                flowId: 'test-flow',
                steps: steps,
              ),
            ),
          ),
        ),
      );

      bloc.add(StepInitialized(steps: steps));
      await tester.pumpAndSettle();

      expect(find.text('PASSO 1 DE 3'), findsOneWidget);
    });

    testWidgets('should show 3 step cards', (WidgetTester tester) async {
      final bloc = StepBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: BlocProvider<StepBloc>.value(
              value: bloc,
              child: StepsPage(
                flowId: 'test-flow',
                steps: steps,
              ),
            ),
          ),
        ),
      );

      bloc.add(StepInitialized(steps: steps));
      await tester.pumpAndSettle();

      expect(find.byType(StepCard), findsNWidgets(3));
    });

    testWidgets('should show navigation buttons', (WidgetTester tester) async {
      final bloc = StepBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: BlocProvider<StepBloc>.value(
              value: bloc,
              child: StepsPage(
                flowId: 'test-flow',
                steps: steps,
              ),
            ),
          ),
        ),
      );

      bloc.add(StepInitialized(steps: steps));
      await tester.pumpAndSettle();

      expect(find.byType(StepNavigationButtons), findsOneWidget);
    });
  });
}
