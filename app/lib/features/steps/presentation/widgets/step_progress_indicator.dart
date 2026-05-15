import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? stepLabel;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isActive = index <= currentStep;
            final isLast = index == totalSteps - 1;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLast ? 0 : 4,
                ),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? palette.primary : palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
        if (stepLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            stepLabel!,
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
