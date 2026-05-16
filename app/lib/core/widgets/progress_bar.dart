import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final ProgressBarAppearance appearance;

  const ProgressBar({
    super.key,
    required this.progress,
    this.appearance = const ProgressBarAppearance(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      width: double.infinity,
      height: appearance.height ?? 4,
      decoration: BoxDecoration(
        color: appearance.backgroundColor ??
            palette.border.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity * progress,
            decoration: BoxDecoration(
              color: appearance.barColor ?? palette.primary,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressBarAppearance {
  final double? height;
  final Color? backgroundColor;
  final Color? barColor;
  final double? borderRadius;

  const ProgressBarAppearance({
    this.height,
    this.backgroundColor,
    this.barColor,
    this.borderRadius,
  });
}
