import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/presentation/widgets/step_content_layout.dart';

void main() {
  group('StepContentLayout', () {
    testWidgets('renders step title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepContentLayout(
            stepTitle: const Text('Step Title'),
            mainContent: const SizedBox(height: 100),
          ),
        ),
      );

      expect(find.text('Step Title'), findsOneWidget);
    });

    testWidgets('renders step description when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepContentLayout(
            stepTitle: const Text('Step Title'),
            stepDescription: const Text('Step Description'),
            mainContent: const SizedBox(height: 100),
          ),
        ),
      );

      expect(find.text('Step Description'), findsOneWidget);
    });

    testWidgets('renders optional contents', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StepContentLayout(
            stepTitle: const Text('Step Title'),
            mainContent: const SizedBox(height: 100),
            optionalContents: [
              const Text('Optional Content 1'),
              const Text('Optional Content 2'),
            ],
          ),
        ),
      );

      expect(find.text('Optional Content 1'), findsOneWidget);
      expect(find.text('Optional Content 2'), findsOneWidget);
    });
  });
}
