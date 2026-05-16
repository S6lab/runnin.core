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

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            children: List.generate(zonePercentages.length, (i) {
              final percentage = zonePercentages[i];
              return Expanded(
                flex: percentage.toInt(),
                child: Container(
                  color: _getZoneColor(i, palette),
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

  Color _getZoneColor(int index, dynamic palette) {
    switch (index) {
      case 0:
        return palette.heartZone1 ?? const Color(0xFF4D7DFF);
      case 1:
        return palette.heartZone2 ?? const Color(0xFF25C56B);
      case 2:
        return palette.heartZone3 ?? const Color(0xFFF3BF31);
      case 3:
        return palette.heartZone4 ?? const Color(0xFFFF6E40);
      case 4:
        return palette.heartZone5 ?? const Color(0xFFFF3B46);
      default:
        return palette.border;
    }
  }
}
