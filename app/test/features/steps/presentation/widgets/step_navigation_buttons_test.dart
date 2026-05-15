import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/presentation/widgets/step_navigation_buttons.dart';

void main() {
  group('StepNavigationButtons', () {
    testWidgets('renders previous button when canGoPrevious is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepNavigationButtons(
            canGoPrevious: true,
            canGoNext: true,
            onPreviousPressed: () {},
            onNextPressed: () {},
          ),
        ),
      );

      expect(find.text('VOLTAR'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_outlined), findsOneWidget);
    });

    testWidgets('hides previous button when canGoPrevious is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepNavigationButtons(
            canGoPrevious: false,
            canGoNext: true,
            onPreviousPressed: () {},
            onNextPressed: () {},
          ),
        ),
      );

      expect(find.text('VOLTAR'), findsNothing);
      expect(find.byIcon(Icons.chevron_left_outlined), findsNothing);
    });

    testWidgets('renders next button and calls callback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepNavigationButtons(
            canGoPrevious: false,
            canGoNext: true,
            onPreviousPressed: () {},
            onNextPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('AVANÇAR'), findsOneWidget);
      await tester.tap(find.text('AVANÇAR'));
      expect(pressed, isTrue);
    });

    testWidgets('shows finish button for last step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepNavigationButtons(
            canGoPrevious: false,
            canGoNext: false,
            onPreviousPressed: () {},
            onNextPressed: () {},
          ),
        ),
      );

      expect(find.text('FINALIZAR'), findsOneWidget);
    });
  });
}
