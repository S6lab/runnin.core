import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/figma_badge_card.dart';

/// Clean BadgeCard wrapper around FigmaBadgeCard
class BadgeCard extends StatelessWidget {
  const BadgeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.progress = 0.0,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final double progress;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return FigmaBadgeCard(
      icon: icon,
      title: title,
      description: description,
      unlocked: unlocked,
      progress: progress,
      accent: accent ?? const Color(0xFF00D4FF),
    );
  }
}
