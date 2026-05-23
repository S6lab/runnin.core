import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Tela combinada "dias disponíveis × treinos/sem". Dias e frequência são
/// INDEPENDENTES: user marca quais dias está disponível (1=seg…7=dom) E
/// quantos treinos quer (freq ≤ qtd de dias marcados). Se freq < dias
/// marcados, a IA escolhe os melhores dias.
class PlanStepDays extends StatelessWidget {
  final Set<int> availableDays;
  final int frequency;
  final ValueChanged<Set<int>> onDaysChange;
  final ValueChanged<int> onFreqChange;

  const PlanStepDays({
    super.key,
    required this.availableDays,
    required this.frequency,
    required this.onDaysChange,
    required this.onFreqChange,
  });

  static const _dayLabels = <String>['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final daysCount = availableDays.length;
    final maxFreq = daysCount == 0 ? 7 : daysCount;
    final freqClamped = frequency.clamp(1, maxFreq);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// SUA ROTINA'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Quando você pode treinar?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Marca os dias da semana em que você consegue treinar — o coach distribui as sessões só nesses dias.',
        ),
        const SizedBox(height: 22),
        // Linha 1: chips de dias da semana.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= 7; i++)
              _DayChip(
                label: _dayLabels[i - 1],
                selected: availableDays.contains(i),
                onTap: () {
                  final next = Set<int>.from(availableDays);
                  if (next.contains(i)) {
                    next.remove(i);
                  } else {
                    next.add(i);
                  }
                  onDaysChange(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 28),
        // Linha 2: stepper de frequência (≤ qtd de dias marcados).
        Text(
          'QUANTOS TREINOS POR SEMANA?',
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepBtn(
              icon: Icons.remove,
              enabled: freqClamped > 1,
              onTap: () => onFreqChange((freqClamped - 1).clamp(1, maxFreq)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.border, width: 1.041),
                ),
                child: Text(
                  '$freqClamped × por semana',
                  style: context.runninType.dataMd.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _StepBtn(
              icon: Icons.add,
              enabled: freqClamped < maxFreq,
              onTap: () => onFreqChange((freqClamped + 1).clamp(1, maxFreq)),
            ),
          ],
        ),
        if (daysCount > 0 && frequency < daysCount) ...[
          const SizedBox(height: 14),
          Text(
            'Você marcou $daysCount dias mas quer treinar $freqClamped× — o coach escolhe os melhores dias.',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.16) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.muted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? palette.primary.withValues(alpha: 0.10) : palette.surface,
          border: Border.all(
            color: enabled ? palette.primary.withValues(alpha: 0.5) : palette.border,
            width: 1.041,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? palette.primary : palette.muted,
          size: 22,
        ),
      ),
    );
  }
}
