import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class FigmaVolumeBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color? barColor;

  const FigmaVolumeBarChart({
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
