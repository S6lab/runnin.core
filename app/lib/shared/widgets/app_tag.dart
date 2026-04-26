import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class AppTag extends StatelessWidget {
  final String label;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const AppTag({
    super.key,
    required this.label,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final accent = color ?? palette.primary;

    return Container(
      padding: padding,
      color: accent.withValues(alpha: 0.12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
