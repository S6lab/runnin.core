import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class RunMetricCell extends StatelessWidget {
  const RunMetricCell({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    
    return FigmaRunMetricCell(
      label: label,
      value: value,
      unit: unit,
      valueColor: palette.primary,
    );
  }
}
