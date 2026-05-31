import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Tooltip compartilhado dos gráficos interativos do Histórico.
/// Mostra o label do bucket + uma linha por série (dot colorido · nome ·
/// valor). Usado pelo TwoToneBarChart e pelo TwoLineChart ao tocar num ponto.
class ChartTooltip extends StatelessWidget {
  final double width;
  final String title;
  final List<ChartTooltipRow> rows;
  const ChartTooltip({
    super.key,
    required this.width,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: type.labelCaps.copyWith(
              color: palette.text,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }
}

class ChartTooltipRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const ChartTooltipRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(width: 7, height: 7, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: type.labelCaps.copyWith(color: palette.muted, fontSize: 8),
            ),
          ),
          Text(
            value,
            style: type.labelCaps.copyWith(
              color: palette.text,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
