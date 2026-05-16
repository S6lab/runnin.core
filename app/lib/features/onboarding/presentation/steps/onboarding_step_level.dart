import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

const kOnboardingLevels = [
  ('iniciante', 'Iniciante', 'Nunca corri ou estou voltando agora'),
  ('intermediario', 'Intermediario', 'Corro regularmente'),
  ('avancado', 'Avancado', 'Treino estruturado'),
];

class OnboardingStepLevel extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const OnboardingStepLevel({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FigmaAssessmentLabel(text: 'ASSESSMENT_01'),
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Qual seu nivel atual?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'O Coach adapta intensidade, volume e progressao ao seu nivel.',
        ),
        const SizedBox(height: 32),
        ...kOnboardingLevels.map((level) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FigmaSelectionButton(
              label: '${level.$2} - ${level.$3}',
              selected: selected == level.$1,
              onTap: () => onSelect(level.$1),
            ),
          );
        }),
      ],
    );
  }
}
