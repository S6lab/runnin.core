import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepBody extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController heightController;

  const OnboardingStepBody({
    super.key,
    required this.weightController,
    required this.heightController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: 'ASSESSMENT_03'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Peso e altura'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'Usamos isso para estimar gasto calorico, zonas e carga de impacto.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: FigmaNumericInputField(
                  label: 'PESO',
                  unit: 'kg',
                  controller: weightController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FigmaNumericInputField(
                  label: 'ALTURA',
                  unit: 'cm',
                  controller: heightController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
