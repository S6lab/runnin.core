import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// 5 objetivos da jornada nova. Cada um tem o label EXATO enviado como `goal`
/// pro server (string livre que o normalizeGoal + resolvePlanWeeksCount
/// entendem); e uma faixa estimada de semanas de preparação só pra UI (não
/// vai pro server — é só pra o user calibrar expectativa).
enum PlanGoalChoice {
  flow(
    'flow',
    'Flow — você contra você mesmo',
    'Sem meta de distância. Plano de melhoria contínua; o checkpoint propõe incrementos semanais.',
    '≈ 8 a 10 semanas',
  ),
  fiveK(
    'Completar 5K',
    '5K',
    'Meta: completar 5K com confiança. Coach define tempo estimado.',
    '6 a 8 semanas',
  ),
  tenK(
    'Completar 10K',
    '10K',
    'Meta: completar 10K com confiança. Pace e volume calibrados.',
    '8 a 10 semanas',
  ),
  halfMarathon(
    'Meia maratona (21K)',
    'Meia maratona (21K)',
    'Bloco mais longo: base + qualidade + long run progressivo.',
    '10 a 14 semanas',
  ),
  marathon(
    'Maratona (42K)',
    'Maratona (42K)',
    'Plano de fundação + bloco específico. Requer base aeróbica formada.',
    '14 a 16 semanas',
  );

  /// Valor exato enviado no campo `goal` do GeneratePlanInput.
  final String backendValue;
  final String label;
  final String description;
  final String weeksRange;
  const PlanGoalChoice(
    this.backendValue,
    this.label,
    this.description,
    this.weeksRange,
  );

  static PlanGoalChoice? fromBackendValue(String? value) {
    if (value == null) return null;
    for (final g in PlanGoalChoice.values) {
      if (g.backendValue == value) return g;
    }
    return null;
  }
}

class PlanStepGoalV2 extends StatelessWidget {
  final PlanGoalChoice? selected;
  final ValueChanged<PlanGoalChoice> onSelect;

  const PlanStepGoalV2({
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
        const FigmaAssessmentLabel(text: '// SEU OBJETIVO'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Qual seu objetivo?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Todos os planos passam pelo checkpoint semanal: o coach gera as 2 próximas semanas detalhadas e ajusta a cada domingo.',
        ),
        const SizedBox(height: 22),
        for (final g in PlanGoalChoice.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GoalChoiceCard(
              choice: g,
              selected: selected == g,
              onTap: () => onSelect(g),
            ),
          ),
      ],
    );
  }
}

class _GoalChoiceCard extends StatelessWidget {
  final PlanGoalChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _GoalChoiceCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    choice.label.toUpperCase(),
                    style: context.runninType.labelMd.copyWith(
                      color: selected ? palette.primary : palette.text,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  choice.weeksRange,
                  style: context.runninType.labelMd.copyWith(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              choice.description,
              style: context.runninType.bodySm.copyWith(
                color: palette.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
