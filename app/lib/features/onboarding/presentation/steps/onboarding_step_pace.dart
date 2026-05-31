import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

const kOnboardingPaceOptions = [
  'Não sei o que é pace',
  'Acima de 7:00/km',
  'Entre 6:00 e 7:00/km',
  'Entre 5:00 e 6:00/km',
  'Abaixo de 5:00/km',
  'Deixa o Coach decidir',
];

class OnboardingStepPace extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const OnboardingStepPace({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Você tem um pace alvo?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Não se preocupe se não sabe — o Coach avalia na primeira corrida e calibra tudo automaticamente.',
        ),
        const SizedBox(height: 24),
        ...kOnboardingPaceOptions.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FigmaSelectionButton(
              label: option,
              selected: selected == option,
              onTap: () => onSelect(option),
            ),
          );
        }),
      ],
    );
  }
}
