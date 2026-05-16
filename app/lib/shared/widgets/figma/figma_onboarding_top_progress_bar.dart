import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaOnboardingTopProgressBar extends StatelessWidget {
  final int total;
  final int currentIndex;

  const FigmaOnboardingTopProgressBar({
    super.key,
    required this.total,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final progress = ((currentIndex + 1) / total).clamp(0.0, 1.0);

    return SizedBox(
      width: double.infinity,
      height: FigmaDimensions.progressBarOnboarding,
      child: Stack(
        children: [
          Container(color: FigmaColors.progressTrack),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(color: FigmaColors.brandCyan),
          ),
        ],
      ),
    );
  }
}
