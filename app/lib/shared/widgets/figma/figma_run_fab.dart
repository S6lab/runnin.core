import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class FigmaRunFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;

  const FigmaRunFAB({
    super.key,
    required this.onPressed,
    this.label = 'RUN',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 55.982,
        height: 55.982,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              palette.primary,
              palette.primary.withValues(alpha: 0.4),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label!,
            style: TextStyle(
              color: palette.background,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
