import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class CardWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget? header;
  final Widget? footer;
  final bool elevation;

  const CardWidget({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.margin,
    this.header,
    this.footer,
    this.elevation = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        border: Border.all(color: borderColor ?? palette.border),
        borderRadius: BorderRadius.zero,
        boxShadow: elevation
            ? [
                BoxShadow(
                  color: palette.text.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: 16),
          ],
          child,
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}
