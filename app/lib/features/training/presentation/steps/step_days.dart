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
        // Linha 2: chips de frequência (1-7) — mesma linguagem visual dos
        // chips de dias acima. Desabilita chips > maxFreq (qtd de dias
        // marcados) pra evitar estado inválido.
        Text(
          'QUANTOS TREINOS POR SEMANA?',
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 1; n <= 7; n++)
              _FreqChip(
                label: '$n',
                selected: freqClamped == n,
                enabled: n <= maxFreq,
                onTap: () => onFreqChange(n),
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

/// Chip de frequência (1-7). Mesma linguagem do _DayChip, com estado
/// disabled (muted + sem tap) quando a opção excede a qtd de dias marcados.
class _FreqChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _FreqChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final fg = !enabled
        ? palette.muted.withValues(alpha: 0.4)
        : selected
            ? palette.primary
            : palette.muted;
    final bg = !enabled
        ? palette.surface
        : selected
            ? palette.primary.withValues(alpha: 0.16)
            : palette.surface;
    final border = !enabled
        ? palette.border.withValues(alpha: 0.5)
        : selected
            ? palette.primary
            : palette.border;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.041),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: fg,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
