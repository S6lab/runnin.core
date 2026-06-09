import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Horizontal stacked bar showing heart zone distribution (Z1-Z5)
/// Usage: FigmaZoneDistributionBar(zonePercentages: [10, 20, 45, 20, 5])
class FigmaZoneDistributionBar extends StatelessWidget {
  final List<double> zonePercentages;
  final double height;

  const FigmaZoneDistributionBar({
    super.key,
    required this.zonePercentages,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    // Todas as zonas em 0%: sem dados de BPM ainda. Em vez de Row
    // colapsado com Expanded(flex: 0) que renderiza vazio (parecia
    // "card branco"), mostra hint explícito.
    final allZero = zonePercentages.every((p) => p <= 0);
    if (allZero) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Sem dados de BPM',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 10,
              color: palette.muted,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            children: List.generate(zonePercentages.length, (i) {
              final percentage = zonePercentages[i];
              // `flex` aceita só int >=0; multiplicamos por 10 pra
              // preservar 1 casa decimal de proporção (12.7% → 127).
              // `max(1, ...)` quando >0 evita Expanded invisível em
              // valores muito pequenos (0.4% → 4 vira 0 sem clamp).
              final flex = percentage <= 0
                  ? 0
                  : math.max(1, (percentage * 10).round());
              return Expanded(
                flex: flex,
                child: Container(
                  color: HeartZoneColors.forZone(i + 1),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(zonePercentages.length, (i) {
            final percentage = zonePercentages[i];
            return Expanded(
              child: Text(
                'Z${i + 1}: ${percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: context.runninType.labelCaps.copyWith(
                  fontSize: 9,
                  color: palette.muted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
