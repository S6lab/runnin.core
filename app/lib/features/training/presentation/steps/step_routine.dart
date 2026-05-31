import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Janela de rotina do atleta — capturada antes do submit do plano.
/// Coach usa pra distribuir sessões duras nos horários de pico de
/// energia + respeitar gap mínimo de 2-3h entre acordar/treinar e
/// treinar/dormir.
///
/// Reusa pattern dos outros steps (chips selecionáveis). Os dados são
/// pré-preenchidos do profile quando o user já passou pelo onboarding
/// routine.
class StepRoutine extends StatelessWidget {
  final String? runPeriod; // 'manha' | 'tarde' | 'noite'
  final String? wakeTime;  // 'HH:MM'
  final String? sleepTime; // 'HH:MM'
  final ValueChanged<String> onPeriodSelect;
  final ValueChanged<String> onWakeTimeSelect;
  final ValueChanged<String> onSleepTimeSelect;

  const StepRoutine({
    super.key,
    required this.runPeriod,
    required this.wakeTime,
    required this.sleepTime,
    required this.onPeriodSelect,
    required this.onWakeTimeSelect,
    required this.onSleepTimeSelect,
  });

  static const _wakeOptions = ['05:00', '06:00', '07:00', '08:00'];
  static const _sleepOptions = ['21:00', '22:00', '23:00', '00:00'];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// ROTINA'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Sua janela de sono e treino'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'Coach distribui as sessões mais duras nos horários de pico '
              'de energia. Gap mínimo de 2-3h entre acordar/treinar e '
              'treinar/dormir.',
        ),
        const SizedBox(height: 24),
        Text(
          'QUANDO PREFERE CORRER?',
          style: type.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PeriodChip(
              icon: Icons.wb_sunny_outlined,
              label: 'MANHÃ',
              hours: '06–09h',
              selected: runPeriod == 'manha',
              onTap: () => onPeriodSelect('manha'),
            ),
            _PeriodChip(
              icon: Icons.wb_twilight,
              label: 'TARDE',
              hours: '14–17h',
              selected: runPeriod == 'tarde',
              onTap: () => onPeriodSelect('tarde'),
            ),
            _PeriodChip(
              icon: Icons.nightlight_outlined,
              label: 'NOITE',
              hours: '19–21h',
              selected: runPeriod == 'noite',
              onTap: () => onPeriodSelect('noite'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACORDA',
                    style: type.labelMd.copyWith(
                      color: palette.muted,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _wakeOptions
                        .map((t) => _TimeChip(
                              label: t,
                              selected: wakeTime == t,
                              onTap: () => onWakeTimeSelect(t),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DORME',
                    style: type.labelMd.copyWith(
                      color: palette.muted,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sleepOptions
                        .map((t) => _TimeChip(
                              label: t,
                              selected: sleepTime == t,
                              onTap: () => onSleepTimeSelect(t),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hours;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({
    required this.icon,
    required this.label,
    required this.hours,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? palette.primary : palette.muted, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.runninType.labelMd.copyWith(
                color: selected ? palette.primary : palette.text,
                letterSpacing: 1.0,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hours,
              style: context.runninType.bodyXs.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TimeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            letterSpacing: 0.8,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
