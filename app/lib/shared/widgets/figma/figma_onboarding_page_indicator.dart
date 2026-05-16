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
    final dots = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i > 0) dots.add(const SizedBox(width: 4));
      if (i == currentIndex) {
        dots.add(const _ActiveDot());
      } else if (i < currentIndex) {
        dots.add(const _VisitedDot());
      } else {
        dots.add(const _InactiveDot());
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots,
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 4,
      color: FigmaColors.brandCyan,
    );
  }
}

class _VisitedDot extends StatelessWidget {
  const _VisitedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 4,
      color: const Color(0x33FFFFFF),
    );
  }
}

class _InactiveDot extends StatelessWidget {
  const _InactiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 4,
      color: const Color(0x0FFFFFFF),
    );
  }
}
