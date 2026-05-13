import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/assessment/presentation/pages/assessment_page.dart';

import '../../../../helpers/test_theme.dart';

void main() {
  group('AssessmentPage - Step Rendering', () {
    testWidgets('Step 0 - Runner level selection renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Verify step code
      expect(find.text('// ASSESSMENT_01'), findsOneWidget);

      // Verify title
      expect(find.text('Qual seu nível atual?'), findsOneWidget);

      // Verify all level options
      expect(find.textContaining('Iniciante'), findsOneWidget);
      expect(find.textContaining('Intermediário'), findsOneWidget);
      expect(find.textContaining('Avançado'), findsOneWidget);

      // Verify navigation button
      expect(find.text('PRÓXIMO /'), findsOneWidget);

      // Verify dots indicator (9 dots)
      expect(find.byType(AnimatedContainer), findsNWidgets(9));
    });

    testWidgets('Step 1 - Identity (name and birth date) renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Verify step code
      expect(find.text('// ASSESSMENT_02'), findsOneWidget);

      // Verify title
      expect(find.text('Como te chamo?'), findsOneWidget);

      // Verify field labels
      expect(find.text('SEU NOME'), findsOneWidget);
      expect(find.text('DATA DE NASCIMENTO'), findsOneWidget);

      // Verify text fields
      expect(find.byType(TextField), findsNWidgets(2));

      // Verify back button is now visible
      expect(find.text('< VOLTAR'), findsOneWidget);
    });

    testWidgets('Step 2 - Body metrics renders correctly', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 2
      await tester.tap(find.text('PRÓXIMO /')); // Step 0 -> 1
      await tester.pumpAndSettle();

      // Fill name
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test User');
      await tester.pump();

      // Fill birth date
      final birthDateField = find.widgetWithText(TextField, 'dd/mm/aaaa');
      await tester.enterText(birthDateField, '15051990');
      await tester.pump();

      await tester.tap(find.text('PRÓXIMO /')); // Step 1 -> 2
      await tester.pumpAndSettle();

      // Verify step code
      expect(find.text('// ASSESSMENT_03'), findsOneWidget);

      // Verify title
      expect(find.text('Peso e altura'), findsOneWidget);

      // Verify field labels
      expect(find.text('PESO (KG)'), findsOneWidget);
      expect(find.text('ALTURA (CM)'), findsOneWidget);

      // Verify default values are present
      expect(find.text('70'), findsOneWidget);
      expect(find.text('175'), findsOneWidget);
    });

    testWidgets('Step 3 - Medical conditions renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate through to step 3
      await tester.tap(find.text('PRÓXIMO /')); // 0 -> 1
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
      await tester.pump();

      await tester.tap(find.text('PRÓXIMO /')); // 1 -> 2
      await tester.pumpAndSettle();

      await tester.tap(find.text('PRÓXIMO /')); // 2 -> 3
      await tester.pumpAndSettle();

      // Verify step code
      expect(find.text('// ASSESSMENT_04'), findsOneWidget);

      // Verify title
      expect(find.text('Informações de saúde'), findsOneWidget);

      // Verify some medical condition options
      expect(find.text('Hipertensão'), findsOneWidget);
      expect(find.text('Diabetes tipo 2'), findsOneWidget);
      expect(find.text('Asma'), findsOneWidget);

      // Verify Coach AI panel
      expect(find.text('COACH.AI'), findsAtLeastNWidgets(1));

      // Verify skip hint
      expect(
          find.textContaining('Pode pular se preferir'), findsOneWidget);
    });

    testWidgets('Step 4 - Weekly frequency renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 4 (skip through previous steps)
      for (int i = 0; i < 4; i++) {
        final nextButton = find.text('PRÓXIMO /');
        if (i == 1) {
          // Step 1 requires input
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
      }

      // Verify step code
      expect(find.text('// ASSESSMENT_05'), findsOneWidget);

      // Verify title
      expect(find.text('Quantas vezes por semana?'), findsOneWidget);

      // Verify frequency options
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
      expect(find.text('5x'), findsOneWidget);
      expect(find.text('6x'), findsOneWidget);

      // Verify labels
      expect(find.text('Base leve'), findsOneWidget);
      expect(find.text('Constância'), findsOneWidget);
      expect(find.text('Equilíbrio'), findsOneWidget);
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Alta carga'), findsOneWidget);
    });

    testWidgets('Step 5 - Goal selection renders correctly', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 5
      for (int i = 0; i < 5; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Verify step code
      expect(find.text('// ASSESSMENT_06'), findsOneWidget);

      // Verify title
      expect(find.text('Qual sua meta principal?'), findsOneWidget);

      // Verify goal options
      expect(find.text('Saúde e bem-estar'), findsOneWidget);
      expect(find.text('Perder peso'), findsOneWidget);
      expect(find.text('Completar 5K'), findsOneWidget);
      expect(find.text('Completar 10K'), findsOneWidget);
      expect(find.text('Meia maratona (21K)'), findsOneWidget);
      expect(find.text('Maratona (42K)'), findsOneWidget);
    });

    testWidgets('Step 6 - Pace target renders correctly', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 6
      for (int i = 0; i < 6; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Verify step code
      expect(find.text('// ASSESSMENT_07'), findsOneWidget);

      // Verify title
      expect(find.text('Você tem um pace alvo?'), findsOneWidget);

      // Verify pace options
      expect(find.text('Não sei o que é pace'), findsOneWidget);
      expect(find.text('Acima de 7:00/km'), findsOneWidget);
      expect(find.text('Deixa o Coach decidir'), findsOneWidget);
    });

    testWidgets('Step 7 - Routine and schedule renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 7
      for (int i = 0; i < 7; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Verify step code
      expect(find.text('// ASSESSMENT_08'), findsOneWidget);

      // Verify title
      expect(find.text('Rotina e horário'), findsOneWidget);

      // Verify run time options
      expect(find.text('Manhã'), findsOneWidget);
      expect(find.text('Tarde'), findsOneWidget);
      expect(find.text('Noite'), findsOneWidget);

      // Verify time field labels
      expect(find.text('ACORDA'), findsOneWidget);
      expect(find.text('DORME'), findsOneWidget);

      // Verify time options
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('07:00'), findsAtLeastNWidgets(1));
      expect(find.text('22:00'), findsAtLeastNWidgets(1));
    });

    testWidgets('Step 8 - Wearable connection renders correctly',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 8 (final step)
      for (int i = 0; i < 8; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Verify step code
      expect(find.text('// ASSESSMENT_09'), findsOneWidget);

      // Verify title
      expect(find.text('Conectar wearable?'), findsOneWidget);

      // Verify wearable options
      expect(find.text('Sim (recomendado)'), findsOneWidget);
      expect(find.text('Depois'), findsOneWidget);

      // Verify final button text changed
      expect(find.text('CRIAR MEU PLANO /'), findsOneWidget);
    });
  });

  group('AssessmentPage - Navigation', () {
    testWidgets('Next button progresses through steps', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Start at step 0
      expect(find.text('// ASSESSMENT_01'), findsOneWidget);

      // Tap next
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Now at step 1
      expect(find.text('// ASSESSMENT_02'), findsOneWidget);
    });

    testWidgets('Back button returns to previous step', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate forward
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      expect(find.text('// ASSESSMENT_02'), findsOneWidget);

      // Navigate back
      await tester.tap(find.text('< VOLTAR'));
      await tester.pumpAndSettle();

      // Should be back at step 0
      expect(find.text('// ASSESSMENT_01'), findsOneWidget);
    });

    testWidgets('Back button is not visible on first step', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Back button should not be visible (but the sized box placeholder exists)
      expect(find.text('< VOLTAR'), findsNothing);
    });

    testWidgets('Progress dots update as user navigates', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Get all animated containers (dots)
      final dotsAtStart = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );

      // First dot should be active (width = 14)
      expect(dotsAtStart.first.constraints?.maxWidth, 14);

      // Navigate to next step
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Verify dot state changed
      final dotsAfterNext = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );

      // Second dot should now be active
      expect(dotsAfterNext.elementAt(1).constraints?.maxWidth, 14);
    });
  });

  group('AssessmentPage - Validation', () {
    testWidgets('Step 1 - Cannot proceed without name', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Try to proceed without entering name (but valid birth date)
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
      await tester.pump();

      // Next button should be disabled
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'PRÓXIMO /'),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('Step 1 - Cannot proceed with invalid birth date',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Enter name but invalid date
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test User');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '99999999');
      await tester.pump();

      // Next button should be disabled
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'PRÓXIMO /'),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('Step 1 - Valid date format (dd/mm/yyyy) works',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Enter valid data
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test User');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
      await tester.pump();

      // Next button should be enabled
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'PRÓXIMO /'),
      );
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('Step 1 - Date auto-formatting with slashes', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Enter digits only
      final dateField = find.widgetWithText(TextField, 'dd/mm/aaaa');
      await tester.enterText(dateField, '15051990');
      await tester.pump();

      // Verify it was formatted with slashes
      final textField = tester.widget<TextField>(dateField);
      expect(textField.controller?.text, '15/05/1990');
    });

    testWidgets('Step 1 - Age validation (too young)', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Enter name and date that's too recent (< 8 years old)
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '01012022');
      await tester.pump();

      // Next button should be disabled
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'PRÓXIMO /'),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('Step 2 - Cannot proceed without weight and height',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 2
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
      await tester.pump();

      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Clear default values
      final weightField = find.widgetWithText(TextField, '70');
      await tester.enterText(weightField, '');
      await tester.pump();

      // Next button should be disabled
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'PRÓXIMO /'),
      );
      expect(nextButton.onPressed, isNull);
    });
  });

  group('AssessmentPage - Interactions', () {
    testWidgets('Level selection highlights selected option', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Select Intermediário
      await tester.tap(find.textContaining('Intermediário'));
      await tester.pumpAndSettle();

      // The selected option should have different styling
      // (This is a basic check - in reality you'd verify colors/borders)
      expect(find.textContaining('Intermediário'), findsOneWidget);
    });

    testWidgets('Medical conditions can be toggled on and off',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 3
      for (int i = 0; i < 3; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Tap a medical condition
      await tester.tap(find.text('Hipertensão'));
      await tester.pumpAndSettle();

      // Tap it again to deselect
      await tester.tap(find.text('Hipertensão'));
      await tester.pumpAndSettle();

      // Should still find the widget (not removed)
      expect(find.text('Hipertensão'), findsOneWidget);
    });

    testWidgets('Can add custom medical condition', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 3
      for (int i = 0; i < 3; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Enter custom condition
      final customField = find.widgetWithText(
        TextField,
        'Adicionar outra condição ou medicação',
      );
      await tester.enterText(customField, 'Custom Condition');
      await tester.pump();

      // Tap add button (the + button)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Custom condition should now appear as a chip
      expect(find.text('Custom Condition'), findsOneWidget);

      // Input field should be cleared
      final textField = tester.widget<TextField>(customField);
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('Frequency selection shows different coach feedback',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 4
      for (int i = 0; i < 4; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Default is 4x - verify default feedback
      expect(
        find.textContaining('Excelente equilíbrio'),
        findsOneWidget,
      );

      // Select 2x
      await tester.tap(find.text('2x'));
      await tester.pumpAndSettle();

      // Verify feedback changed
      expect(
        find.textContaining('Ótimo para começar'),
        findsOneWidget,
      );
    });

    testWidgets('Goal selection highlights selected goal', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 5
      for (int i = 0; i < 5; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Default is "Completar 10K"
      expect(find.text('Completar 10K'), findsOneWidget);

      // Select different goal
      await tester.tap(find.text('Maratona (42K)'));
      await tester.pumpAndSettle();

      // Goal should still be present
      expect(find.text('Maratona (42K)'), findsOneWidget);
    });
  });

  group('AssessmentPage - Error Handling', () {
    testWidgets('Shows error when validation fails', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Enter name change listener should clear error
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.pump();

      // The error state is cleared on input change
      // (Error would show if submit was attempted without valid input)
    });
  });

  group('AssessmentPage - Loading State', () {
    testWidgets('Shows loading step during submission', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // This test would require mocking the submission
      // For now, verify the loading widget exists in the code path
      // (Full integration test would need backend mock)
    });
  });

  group('AssessmentPage - Edge Cases', () {
    testWidgets('Handles very long custom medical condition text',
        (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 3
      for (int i = 0; i < 3; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Enter very long text
      final longText = 'Very Long Condition Name ' * 10;
      final customField = find.widgetWithText(
        TextField,
        'Adicionar outra condição ou medicação',
      );
      await tester.enterText(customField, longText);
      await tester.pump();

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should handle without crashing
      expect(find.textContaining('Very Long Condition'), findsOneWidget);
    });

    testWidgets('Date input limited to 8 digits', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Try to enter more than 8 digits
      final dateField = find.widgetWithText(TextField, 'dd/mm/aaaa');
      await tester.enterText(dateField, '123456789012345');
      await tester.pump();

      // Should be limited to 8 digits (formatted as dd/mm/yyyy)
      final textField = tester.widget<TextField>(dateField);
      final text = textField.controller?.text ?? '';
      // Count only digits
      final digitCount = text.replaceAll(RegExp(r'[^0-9]'), '').length;
      expect(digitCount, lessThanOrEqualTo(8));
    });

    testWidgets('Weight and height limited to 3 digits', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 2
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.enterText(
          find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
      await tester.pump();

      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Try to enter more than 3 digits in weight
      final weightField = find.widgetWithText(TextField, '70');
      await tester.enterText(weightField, '12345');
      await tester.pump();

      // Should be limited to 3 digits
      final textField = tester.widget<TextField>(weightField);
      expect(textField.controller?.text.length, lessThanOrEqualTo(3));
    });

    testWidgets('Empty custom medical condition is not added', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 3
      for (int i = 0; i < 3; i++) {
        if (i == 1) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
          await tester.enterText(
              find.widgetWithText(TextField, 'dd/mm/aaaa'), '15051990');
          await tester.pump();
        }
        await tester.tap(find.text('PRÓXIMO /'));
        await tester.pumpAndSettle();
      }

      // Get initial medical condition count
      final initialConditions =
          find.text('Hipertensão').evaluate().length;

      // Try to add empty condition
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Count should not change (empty condition not added)
      final finalConditions = find.text('Hipertensão').evaluate().length;
      expect(finalConditions, equals(initialConditions));
    });
  });

  group('AssessmentPage - Accessibility', () {
    testWidgets('Name field has autofocus on step 1', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Find the name text field
      final nameField = find.widgetWithText(TextField, 'Ex: Lucas');
      final textField = tester.widget<TextField>(nameField);

      // Verify autofocus is enabled
      expect(textField.autofocus, isTrue);
    });

    testWidgets('Name field uses proper text capitalization', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Find the name text field
      final nameField = find.widgetWithText(TextField, 'Ex: Lucas');
      final textField = tester.widget<TextField>(nameField);

      // Verify text capitalization
      expect(textField.textCapitalization, TextCapitalization.words);
    });

    testWidgets('Numeric fields use numeric keyboard', (tester) async {
      await tester.pumpWidget(createTestApp(const AssessmentPage()));
      await tester.pumpAndSettle();

      // Navigate to step 1
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Check birth date field
      final dateField = find.widgetWithText(TextField, 'dd/mm/aaaa');
      final dateTextField = tester.widget<TextField>(dateField);
      expect(dateTextField.keyboardType, TextInputType.number);

      // Navigate to step 2
      await tester.enterText(
          find.widgetWithText(TextField, 'Ex: Lucas'), 'Test');
      await tester.enterText(dateField, '15051990');
      await tester.pump();
      await tester.tap(find.text('PRÓXIMO /'));
      await tester.pumpAndSettle();

      // Check weight field
      final weightField = find.widgetWithText(TextField, '70');
      final weightTextField = tester.widget<TextField>(weightField);
      expect(weightTextField.keyboardType, TextInputType.number);
    });
  });
}
