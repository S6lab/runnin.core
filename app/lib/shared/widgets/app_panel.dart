import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

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
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        // Padrão: tom escuro levemente opaco (mesmo de _StatusCorporal).
        // Callers podem overridar com `color:` pra mudar (errors, warnings, etc).
        color: color ?? FigmaColors.surfaceCard,
        border: Border.all(
          color: borderColor ?? FigmaColors.borderDefault,
          width: 1.041,
        ),
      ),
      child: child,
    );
  }
}
