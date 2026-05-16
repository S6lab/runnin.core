import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaOnboardingPageIndicator extends StatelessWidget {
  final int total;
  final int currentIndex;

  const FigmaOnboardingPageIndicator({
    super.key,
    required this.total,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool isActive = i == currentIndex;
        final bool isVisited = i < currentIndex;

        final Color color;
        if (isActive) {
          color = FigmaColors.dotActive;
        } else if (isVisited) {
          color = FigmaColors.dotVisited;
        } else {
          color = FigmaColors.dotInactive;
        }

        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
          child: Container(
            width: isActive ? 20 : 6,
            height: 4,
            color: color,
          ),
        );
      }),
    );
  }
}
