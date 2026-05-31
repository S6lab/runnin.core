import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class RunStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RunStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? palette.primary : palette.border,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        );
      }),
    );
  }
}
