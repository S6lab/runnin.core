import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Streak calendar 7×4 grid per `docs/figma/screens/PERFIL.md` §GAMIFICAÇÃO
/// > STREAK. Active days render with cyan fill at progressive opacity
/// (30%–94% gradient based on position). Inactive cells are dim.
///
/// [activeDays] is a list of 0-indexed day positions (0..27) that are filled.
class FigmaStreakCalendarGrid extends StatelessWidget {
  const FigmaStreakCalendarGrid({
    super.key,
    required this.activeDays,
    this.cellSize = 40.9,
    this.gap = 4,
  });

  final List<int> activeDays;
  final double cellSize;
  final double gap;

  static const _weekdayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final activeSet = activeDays.toSet();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int col = 0; col < 7; col++) ...[
              if (col > 0) SizedBox(width: gap),
              SizedBox(
                width: cellSize,
                child: Text(
                  _weekdayLabels[col],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: gap * 2),
        for (int row = 0; row < 4; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int col = 0; col < 7; col++) ...[
                if (col > 0) SizedBox(width: gap),
                _Cell(
                  size: cellSize,
                  active: activeSet.contains(row * 7 + col),
                  // Gradient opacity from 30% to 94% across the 28 cells
                  opacity: 0.30 + (row * 7 + col) * (0.94 - 0.30) / 27,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.size, required this.active, required this.opacity});

  final double size;
  final bool active;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: active
            ? FigmaColors.brandCyan.withValues(alpha: opacity.clamp(0.30, 0.94))
            : FigmaColors.surfaceCard,
      ),
    );
  }
}
