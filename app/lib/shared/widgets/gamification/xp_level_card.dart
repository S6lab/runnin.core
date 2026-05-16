import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/figma_xp_level_card.dart';

/// Clean XPLevelCard wrapper around FigmaXpLevelCard
class XPLevelCard extends StatelessWidget {
  const XPLevelCard({
    super.key,
    required this.level,
    required this.levelLabel,
    required this.currentXp,
    required this.nextLevelXp,
  });

  final int level;
  final String levelLabel;
  final int currentXp;
  final int nextLevelXp;

  @override
  Widget build(BuildContext context) {
    return FigmaXpLevelCard(
      level: level,
      levelLabel: levelLabel,
      currentXp: currentXp,
      nextLevelXp: nextLevelXp,
    );
  }
}
