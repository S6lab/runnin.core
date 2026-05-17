import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class MonthWeekCard extends StatelessWidget {
  const MonthWeekCard({
    super.key,
    required this.weekNumber,
    required this.focus,
    required this.summary,
    required this.totalDistance,
    required this.status,
    required this.statusColor,
  });

  final int weekNumber;
  final String focus;
  final String summary;
  final double totalDistance;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: status == 'ATUAL'
          ? palette.primary.withValues(alpha: 0.45)
          : palette.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sem $weekNumber  Foco: $focus',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: TextStyle(color: palette.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalDistance.toStringAsFixed(0)}K',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: palette.secondary,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.08,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
