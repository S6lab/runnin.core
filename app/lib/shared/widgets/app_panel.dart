import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        border: Border.all(color: borderColor ?? palette.border, width: 1.735),
      ),
      child: child,
    );
  }
}
