import 'package:flutter/material.dart';
import 'package:runnin/core/constants/marketing_copy.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepRoutine extends StatelessWidget {
  final String? selectedPeriod;
  final String? selectedWakeTime;
  final String? selectedSleepTime;
  final ValueChanged<String> onPeriodSelect;
  final ValueChanged<String> onWakeTimeSelect;
  final ValueChanged<String> onSleepTimeSelect;

  const OnboardingStepRoutine({
    super.key,
    required this.selectedPeriod,
    required this.selectedWakeTime,
    required this.selectedSleepTime,
    required this.onPeriodSelect,
    required this.onWakeTimeSelect,
    required this.onSleepTimeSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Rotina e horário'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text: MarketingCopy.routineDescription,
          ),
          const SizedBox(height: 24),
          Text(
            'QUANDO PREFERE CORRER?',
            style: context.runninType.bodyXs.copyWith(
              letterSpacing: 1.65,
              color: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FigmaTimePeriodCard(
                icon: Icons.wb_sunny_outlined,
                label: 'Manhã',
                hours: '06-09h',
                hint: MarketingCopy.routineHintManha,
                selected: selectedPeriod == 'manha',
                onTap: () => onPeriodSelect('manha'),
              ),
              const SizedBox(width: 8),
              FigmaTimePeriodCard(
                icon: Icons.wb_twilight,
                label: 'Tarde',
                hours: '14-17h',
                hint: MarketingCopy.routineHintTarde,
                selected: selectedPeriod == 'tarde',
                onTap: () => onPeriodSelect('tarde'),
              ),
              const SizedBox(width: 8),
              FigmaTimePeriodCard(
                icon: Icons.nightlight_outlined,
                label: 'Noite',
                hours: '19-21h',
                hint: MarketingCopy.routineHintNoite,
                selected: selectedPeriod == 'noite',
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
                      style: context.runninType.bodyXs.copyWith(
                        letterSpacing: 1.65,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...['05:00', '06:00', '07:00', '08:00'].map(
                      (time) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _TimeOptionButton(
                          label: time,
                          selected: selectedWakeTime == time,
                          onTap: () => onWakeTimeSelect(time),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DORME',
                      style: context.runninType.bodyXs.copyWith(
                        letterSpacing: 1.65,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...['21:00', '22:00', '23:00', '00:00'].map(
                      (time) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _TimeOptionButton(
                          label: time,
                          selected: selectedSleepTime == time,
                          onTap: () => onSleepTimeSelect(time),
                        ),
                      ),
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

class _TimeOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOptionButton({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44.5,
        decoration: BoxDecoration(
          color: selected
              ? FigmaColors.selectionActiveBg
              : FigmaColors.surfaceCard,
          border: Border.all(
            color: selected
                ? FigmaColors.selectionActiveBorder
                : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.runninType.bodyMd.copyWith(
            color: selected
                ? FigmaColors.textPrimary
                : FigmaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
