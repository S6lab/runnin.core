import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class CoachAICard extends StatelessWidget {
  const CoachAICard({
    super.key,
    required this.title,
    required this.children,
    this.borderColor,
  });

  final String title;
  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final border = borderColor ?? palette.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: border, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.runninType.labelCaps.copyWith(color: border),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
