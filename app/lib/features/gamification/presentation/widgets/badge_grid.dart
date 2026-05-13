import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/achievement_card.dart';

class BadgeDefinition {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final double progress;

  const BadgeDefinition({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.progress,
  });
}

class BadgeGrid extends StatelessWidget {
  final List<BadgeDefinition> badges;
  final int columns;

  const BadgeGrid({
    super.key,
    required this.badges,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BADGES (${badges.where((b) => b.unlocked).length}/${badges.length})',
          style: type.displayMd,
        ),
        const SizedBox(height: 16),
        ...List.generate((badges.length / columns).ceil(), (row) {
          final start = row * columns;
          final rowBadges = badges.sublist(
            start,
            (start + columns).clamp(0, badges.length),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowBadges.map((b) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: rowBadges.indexOf(b) > 0 ? 4 : 0,
                  ),
                  child: AchievementCard(
                    title: b.title,
                    description: b.description,
                    icon: b.icon,
                    isUnlocked: b.unlocked,
                    progress: b.progress,
                  ),
                ),
              )).toList(),
            ),
          );
        }),
      ],
    );
  }
}
