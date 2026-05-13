import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class XpProgressWidget extends StatelessWidget {
  final int level;
  final int totalXp;
  final int xpInLevel;
  final int xpToNext;
  final double progress;
  final VoidCallback? onTap;

  const XpProgressWidget({
    super.key,
    required this.level,
    required this.totalXp,
    required this.xpInLevel,
    required this.xpToNext,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.2),
                    border: Border.all(color: palette.primary, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$level',
                    style: type.dataLg.copyWith(
                      color: palette.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nível $level',
                        style: type.labelMd,
                      ),
                      Text(
                        '$xpInLevel / 500 XP • Falta $xpToNext XP',
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
            const SizedBox(height: 12),
            ClipRect(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
