import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepFrequency extends StatelessWidget {
  final int frequency;
  final ValueChanged<int> onFreqChange;

  const OnboardingStepFrequency({
    super.key,
    required this.frequency,
    required this.onFreqChange,
  });

  @override
  Widget build(BuildContext context) {
    const options = <int, String>{
      2: '2x',
      3: '3x',
      4: '4x',
      5: '5x',
      6: '6x+',
    };
    final coachNotes = <int, String>{
      2: 'Otimo para comecar com constancia sem pesar a rotina. Vamos priorizar adaptacao e recuperacao.',
      3: 'Boa frequencia para criar base com seguranca. Ja da para evoluir volume e ritmo aos poucos.',
      4: 'Excelente equilibrio entre progresso e recuperacao. Costuma render planos bem completos.',
      5: 'Frequencia forte. O Coach vai distribuir carga com mais precisao para evitar excesso.',
      6: 'Rotina de alto compromisso. Vamos controlar intensidade para sustentar consistencia.',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Quantas vezes por semana?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach distribui sessões com descanso adequado entre cada corrida.',
          ),
          const SizedBox(height: 24),
          ...options.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FigmaSelectionButton(
                label: e.value,
                selected: frequency == e.key,
                onTap: () => onFreqChange(e.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FigmaCoachAIBreadcrumb(action: 'NOTA'),
                const SizedBox(height: 12),
                FigmaAssessmentDescription(text: coachNotes[frequency]!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
