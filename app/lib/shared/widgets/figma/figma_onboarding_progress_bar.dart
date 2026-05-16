import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Onboarding progress bar following Figma design
/// Height: 2px, fill color is ciano (primary) proportional to step progress
class FigmaOnboardingProgressBar extends StatelessWidget {
  final double currentStep;
  final double totalSteps;

  const FigmaOnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final progressValue = (currentStep / totalSteps).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: 2,
      color: palette.border,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progressValue,
        child: Container(color: palette.primary),
      ),
    );
  }
}
