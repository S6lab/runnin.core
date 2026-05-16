import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// 5-segment Z1–Z5 cardio zone bar per DESIGN_SYSTEM.md §2.8.
/// Colors are canonical (`FigmaColors.zone1..zone5`); each segment's
/// width is proportional to [proportions] (length 5, sum should be ~1.0).
///
/// Pass [highlightedZone] (1..5) to optionally dim the other zones —
/// useful as a "current zone" indicator during an active run.
class FigmaZoneBar extends StatelessWidget {
  const FigmaZoneBar({
    super.key,
    this.proportions,
    this.height = 8.0,
    this.highlightedZone,
  });

  final List<double>? proportions;
  final double height;
  final int? highlightedZone;

  static const _zones = [
    FigmaColors.zone1,
    FigmaColors.zone2,
    FigmaColors.zone3,
    FigmaColors.zone4,
    FigmaColors.zone5,
  ];

  @override
  Widget build(BuildContext context) {
    final p = proportions ?? const [0.2, 0.2, 0.2, 0.2, 0.2];
    assert(p.length == 5, 'FigmaZoneBar expects 5 proportions');
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (int i = 0; i < _zones.length; i++)
            Expanded(
              flex: (p[i] * 1000).round().clamp(1, 1000),
              child: Opacity(
                opacity: highlightedZone == null || highlightedZone == i + 1
                    ? 1.0
                    : 0.3,
                child: ColoredBox(color: _zones[i]),
              ),
            ),
        ],
      ),
    );
  }
}
