import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class BodyMetricsGrid extends StatelessWidget {
  final String? weight;
  final String? height;
  final bool enabled;

  const BodyMetricsGrid({
    super.key,
    required this.weight,
    required this.height,
    this.enabled = false,
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
            style: context.runninType.labelCaps.copyWith(
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 17.7),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'PESO',
                  value: weight ?? '-- kg',
                  suffix: 'kg',
                  enabled: enabled,
                  palette: palette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17.7),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'ALTURA',
                  value: height ?? '-- cm',
                  suffix: 'cm',
                  enabled: enabled,
                  palette: palette,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final bool enabled;
  final RunninPalette palette;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.enabled,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17.7),
      decoration: BoxDecoration(
        color: enabled ? palette.surface : palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.runninType.labelCaps.copyWith(
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.runninType.displaySm.copyWith(
              color: enabled ? palette.text : palette.muted,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suffix,
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
