import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

const kOnboardingGoals = [
  'Saúde e bem-estar',
  'Perder peso',
  'Completar 5K',
  'Completar 10K',
  'Meia maratona (21K)',
  'Maratona (42K)',
  'Ultramaratona',
  'Triathlon',
];

class OnboardingStepGoal extends StatelessWidget {
  final String selectedGoal;
  final ValueChanged<String> onGoalSelect;

  const OnboardingStepGoal({
    super.key,
    required this.selectedGoal,
    required this.onGoalSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Qual sua meta principal?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach monta periodização, volume e progressão com base no seu objetivo.',
          ),
          const SizedBox(height: 24),
          ...kOnboardingGoals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FigmaSelectionButton(
                label: goal,
                selected: selectedGoal == goal,
                onTap: () => onGoalSelect(goal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
