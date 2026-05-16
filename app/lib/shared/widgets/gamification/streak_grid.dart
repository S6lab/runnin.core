import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/figma_streak_calendar_grid.dart';

/// Clean StreakGrid wrapper around FigmaStreakCalendarGrid
class StreakGrid extends StatelessWidget {
  const StreakGrid({
    super.key,
    required this.activeDays,
    this.cellSize = 40.9,
    this.gap = 4,
  });

  final List<int> activeDays;
  final double cellSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return FigmaStreakCalendarGrid(
      activeDays: activeDays,
      cellSize: cellSize,
      gap: gap,
    );
  }
}
