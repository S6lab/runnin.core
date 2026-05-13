import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class StreakWidget extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final VoidCallback? onTap;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: AppPanel(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: currentStreak > 0
                    ? palette.primary.withValues(alpha: 0.2)
                    : palette.border,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.local_fire_department,
                color: currentStreak > 0 ? palette.primary : palette.muted,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$currentStreak',
                        style: type.dataLg.copyWith(
                          color: currentStreak > 0 ? palette.primary : palette.text,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentStreak == 1 ? 'dia' : 'dias',
                        style: type.labelMd.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    longestStreak > currentStreak
                        ? 'Recorde: $longestStreak dias'
                        : currentStreak > 0
                            ? 'Continue assim!'
                            : 'Comece sua sequência',
                    style: type.bodySm.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: palette.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
