import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
import 'package:runnin/core/theme/app_palette.dart';

class PostRunStatCard extends StatelessWidget {
  const PostRunStatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = FigmaColors.brandCyan,
  });

  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return FigmaPostRunStatCard(
      label: label,
      value: value,
      unit: unit,
      valueColor: valueColor,
    );
  }
}
