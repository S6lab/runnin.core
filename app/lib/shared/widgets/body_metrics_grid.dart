import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class BodyMetricsGrid extends StatelessWidget {
  final double? weight;
  final double? height;
  final int? age;
  final int? weeklyFrequency;

  const BodyMetricsGrid({
    super.key,
    this.weight,
    this.height,
    this.age,
    this.weeklyFrequency,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Padding(
      padding: const EdgeInsets.all(17.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MÉTRICAS CORPORAIS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: palette.muted,
              letterSpacing: 0.12,
            ),
          ),
          const SizedBox(height: 17.7),
          Row(
            children: [
              _buildMetricCell(palette, 'PESO', weight, 'kg'),
              _buildMetricCell(palette, 'ALTURA', height, 'cm'),
              _buildMetricCell(palette, 'IDADE', age, 'anos'),
              _buildMetricCell(palette, 'FREQ', weeklyFrequency, 'x/semana'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(
    RunninPalette palette,
    String label,
    dynamic value,
    String unit,
  ) {
    final formattedValue = value == null ? '—' : '$value';
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 1.041),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: palette.muted,
                letterSpacing: 0.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formattedValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
