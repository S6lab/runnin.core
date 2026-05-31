import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.kmLabel,
    required this.time,
    required this.barRatio,
    this.isBest = false,
  });

  final String kmLabel;
  final String time;
  final double barRatio;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    return FigmaSplitRow(
      kmLabel: kmLabel,
      time: time,
      barRatio: barRatio,
      isBest: isBest,
    );
  }
}
