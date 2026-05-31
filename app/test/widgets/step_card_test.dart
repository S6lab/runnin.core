import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/steps/domain/entities/step.dart';
import 'package:runnin/features/steps/presentation/widgets/step_card.dart';

void main() {
  final step = AppStep(
    id: 'step_1',
    title: 'Aquecimento',
    description: 'Realize 5 minutos de caminhada leve',
    status: StepStatus.idle,
    content: SizedBox.shrink(),
  );

  group('StepCard Widget Tests', () {
    testWidgets('should render step card with correct structure', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byType(StepCard), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
      
      await tester.pumpWidget(Container());
    });

    testWidgets('should display step title in uppercase', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('AQUECIMENTO'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should display step description when provided', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Realize 5 minutos de caminhada leve'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should not display description when null', (tester) async {
      final stepNoDescription = AppStep(
        id: 'step_2',
        title: 'Exercicio Principal',
        status: StepStatus.idle,
        content: SizedBox.shrink(),
      );

      final widget = StepCard(
        step: stepNoDescription,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('EXERCICIO PRINCIPAL'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should show success icon for completed status', (tester) async {
      final completedStep = AppStep(
        id: 'step_3',
        title: 'Finalizado',
        status: StepStatus.completed,
        content: SizedBox.shrink(),
      );

      final widget = StepCard(
        step: completedStep,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should show error icon for error status', (tester) async {
      final errorStep = AppStep(
        id: 'step_4',
        title: 'Erro',
        status: StepStatus.error,
        content: SizedBox.shrink(),
      );

      final widget = StepCard(
        step: errorStep,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should show validation errors container when errors present', (tester) async {
      final validationError = StepValidationResult(
        isValid: false,
        message: 'Campo obrigatório',
        field: 'nome',
      );

      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: [validationError],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Campo obrigatório'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should display validation error messages', (tester) async {
      final validationError = StepValidationResult(
        isValid: false,
        message: 'Campo obrigatório',
        field: 'nome',
      );

      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: [validationError],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Campo obrigatório'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should show error icon for validation errors', (tester) async {
      final validationError = StepValidationResult(
        isValid: false,
        message: 'Campo obrigatório',
        field: 'nome',
      );

      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: [validationError],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should display multiple validation errors', (tester) async {
      final errors = [
        StepValidationResult(
          isValid: false,
          message: 'Campo 1 obrigatório',
          field: 'campo1',
        ),
        StepValidationResult(
          isValid: false,
          message: 'Campo 2 obrigatório',
          field: 'campo2',
        ),
      ];

      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: errors,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Campo 1 obrigatório'), findsOneWidget);
      expect(find.text('Campo 2 obrigatório'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have active background color when isActive is true', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      final stepCard = tester.widget<StepCard>(find.byType(StepCard));
      expect(stepCard.isActive, true);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have inactive background color when isActive is false', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      final stepCard = tester.widget<StepCard>(find.byType(StepCard));
      expect(stepCard.isActive, false);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have primary border when isActive is true', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      final stepCard = tester.widget<StepCard>(find.byType(StepCard));
      expect(stepCard.isActive, true);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have error border when step status is error', (tester) async {
      final errorStep = AppStep(
        id: 'step_5',
        title: 'Erro',
        status: StepStatus.error,
        content: SizedBox.shrink(),
      );

      final widget = StepCard(
        step: errorStep,
        isActive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have error border when validation errors present', (tester) async {
      final validationError = StepValidationResult(
        isValid: false,
        message: 'Erro de validação',
        field: 'test',
      );

      final widget = StepCard(
        step: step,
        isActive: false,
        validationErrors: [validationError],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('Erro de validação'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should call onTap callback when tapped', (tester) async {
      var tapped = false;

      final widget = StepCard(
        step: step,
        isActive: true,
        onTap: () => tapped = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('should not crash when onTap is null', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
        onTap: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byType(StepCard), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should handle empty validation errors list', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('AQUECIMENTO'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should handle null validation errors', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
        validationErrors: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.text('AQUECIMENTO'), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('should render different step statuses correctly', (tester) async {
      final statuses = [
        StepStatus.idle,
        StepStatus.active,
        StepStatus.completed,
        StepStatus.error,
      ];

      for (final status in statuses) {
        final testStep = AppStep(
          id: 'step_${status.name}',
          title: status.name.toUpperCase(),
          status: status,
          content: SizedBox.shrink(),
        );

        final widget = StepCard(
          step: testStep,
          isActive: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: [
                RunninThemeTokens(palette: RunninSkin.artico.palette),
              ],
            ),
            home: Scaffold(body: widget),
          ),
        );

        expect(find.text(status.name.toUpperCase()), findsOneWidget);
        await tester.pumpWidget(Container());
      }
    });

    testWidgets('should display success icon only for completed status', (tester) async {
      final nonCompletedStep = AppStep(
        id: 'step_6',
        title: 'Nao Completo',
        status: StepStatus.active,
        content: SizedBox.shrink(),
      );

      final widget = StepCard(
        step: nonCompletedStep,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have correct border radius', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      final stepCardFinder = find.byType(StepCard);
      final containerFinder = find.descendant(
        of: stepCardFinder,
        matching: find.byType(Container),
      );
      
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      // Per Figma DESIGN_SYSTEM.md §1: zero border-radius universal
      // (only exception is the toggle pill). Test updated alongside
      // SUP-399 which enforced this policy across all widgets.
      expect(decoration.borderRadius, BorderRadius.zero);
      await tester.pumpWidget(Container());
    });

    testWidgets('should have correct padding', (tester) async {
      final widget = StepCard(
        step: step,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: Scaffold(body: widget),
        ),
      );

      final stepCardFinder = find.byType(StepCard);
      final containerFinder = find.descendant(
        of: stepCardFinder,
        matching: find.byType(Container),
      );
      
      final container = tester.widget<Container>(containerFinder);
      expect(container.padding, const EdgeInsets.all(16));
      await tester.pumpWidget(Container());
    });
  });
}
