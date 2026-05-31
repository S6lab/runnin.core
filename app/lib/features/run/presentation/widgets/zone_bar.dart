import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class ZoneBar extends StatelessWidget {
  const ZoneBar({
    super.key,
    this.proportions,
    this.highlightedZone,
  });

  final List<double>? proportions;
  final int? highlightedZone;

  @override
  Widget build(BuildContext context) {
    return FigmaZoneBar(
      proportions: proportions,
      highlightedZone: highlightedZone,
    );
  }
}
