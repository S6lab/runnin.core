import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Card de conquista desbloqueada ou em progresso.
/// Usado na tela de gamificação (galeria de badges).
class AchievementCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final double progress; // 0.0–1.0

  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final color = isUnlocked ? palette.primary : palette.muted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? palette.primary.withValues(alpha: 0.08)
            : palette.surface,
        border: Border.all(
          color: isUnlocked
              ? palette.primary.withValues(alpha: 0.4)
              : palette.border,
          width: 1.735,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
              if (isUnlocked)
                Icon(Icons.verified, size: 14, color: palette.primary)
              else
                Text(
                  '${(progress * 100).toInt()}%',
                  style: type.labelCaps.copyWith(color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title.toUpperCase(),
            style: type.labelMd.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(description, style: type.bodySm),
             if (!isUnlocked && progress != null) ...[
               const SizedBox(height: 10),
               ClipRect(
                 child: Container(
                   height: 4,
                color: palette.border,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: palette.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
