import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Container semântico para painéis de gráfico.
/// Envolve o widget de chart com header e borda padrão do design system.
/// O chart em si é passado como child (fl_chart, custom painter, etc.).
class ChartPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;

  const ChartPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: type.displaySm.copyWith(fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: type.bodySm),
          ],
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

/// Barra simples para gráficos de volume (sem dependência externa).
/// Use fl_chart para charts mais complexos — este é o fallback inline.
class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color? barColor;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final color = barColor ?? palette.primary;
    final maxVal = values.fold(0.0, (m, v) => v > m ? v : m);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final frac = maxVal > 0 ? values[i] / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        FractionallySizedBox(
                          heightFactor: frac.clamp(0.02, 1.0),
                          child: Container(color: color.withValues(alpha: 0.85)),
                        )
                      else
                        Container(height: 4, color: palette.border),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) => Expanded(
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: type.labelCaps.copyWith(fontSize: 8),
            ),
          )),
        ),
      ],
    );
  }
}
