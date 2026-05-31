import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class GamificationStatsRow extends StatelessWidget {
  final StatData streak;
  final StatData xp;
  final StatData badges;

  const GamificationStatsRow({
    super.key,
    required this.streak,
    required this.xp,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCell(label: 'STREAK', value: streak.value, color: const Color(0xFF00D4FF))),
        const SizedBox(width: 8),
        Expanded(child: _StatCell(label: 'XP', value: xp.value, color: const Color(0xFFFF6B35), accent: true)),
        const SizedBox(width: 8),
        Expanded(child: _StatCell(label: 'BADGES', value: badges.value, color: const Color(0xFFFFFFFF))),
      ],
    );
  }
}

class StatData {
  final String label;
  final String value;
  final bool accent;

  const StatData({
    required this.label,
    required this.value,
    this.accent = false,
  });
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool accent;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: accent
            ? RadialGradient(
                center: const Alignment(0.0, -0.5),
                colors: [
                  color.withValues(alpha: 0.16),
                  palette.surface,
                ],
                stops: const [0.0, 1.0],
              )
            : null,
        color: accent ? null : palette.surface,
        border: Border.all(color: accent ? color.withValues(alpha: 0.4) : palette.border),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: accent ? color : palette.muted,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: accent ? color : palette.text,
              letterSpacing: -0.02,
            ),
          ),
        ],
      ),
    );
  }
}
