import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

const kOnboardingGenderOptions = [
  ('male', 'Masculino'),
  ('female', 'Feminino'),
  ('other', 'Outro'),
  ('na', 'Prefiro não informar'),
];

class OnboardingStepGender extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const OnboardingStepGender({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Como você se identifica?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach usa para calcular FC máxima (Tanaka para M, Gulati para F), zonas cardíacas e personalizar recomendações com base em literatura de corrida.',
          ),
          const SizedBox(height: 32),
          ...kOnboardingGenderOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FigmaSelectionButton(
                label: option.$2,
                selected: selected == option.$1,
                onTap: () => onSelect(option.$1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
