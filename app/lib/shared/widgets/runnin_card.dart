import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Card padrão do design system runnin.
///
/// Encapsula o trio: `border 1px palette.border + radius zero + padding
/// AppSpacing.xl (16)` que se repete em ~80% dos containers das páginas.
/// Antes cada página redeclarava manualmente isso com pequenas variações
/// (12, 14, 16) — virou inconsistência visual.
///
/// Variantes:
///  - `accent: 'cyan'` / `'orange'` → border-left colorida 2.5px
///    (replicando o padrão Coach.AI da home)
///  - `dense: true` → padding 12px em vez de 16 (sub-cards)
///  - `padding` override quando necessário (raríssimo, prefira variantes)
class RunninCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool dense;
  final String? accent; // 'cyan' | 'orange' | null
  final VoidCallback? onTap;

  const RunninCard({
    super.key,
    required this.child,
    this.padding,
    this.dense = false,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final accentColor = accent == 'cyan'
        ? context.runninPalette.primary
        : accent == 'orange'
            ? context.runninPalette.secondary
            : null;

    final effectivePadding = padding ??
        EdgeInsets.all(dense ? AppSpacing.lg : AppSpacing.xl);

    final container = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: accentColor != null
            ? Border(
                left: BorderSide(color: accentColor, width: 2.5),
                top: BorderSide(color: palette.border),
                right: BorderSide(color: palette.border),
                bottom: BorderSide(color: palette.border),
              )
            : Border.all(color: palette.border),
      ),
      child: child,
    );

    if (onTap == null) return container;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: container,
    );
  }
}
