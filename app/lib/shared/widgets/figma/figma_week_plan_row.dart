import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Single weekly-plan row in TREINO §Plano Semanal per
/// `docs/figma/screens/TREINO.md` tela 1. Renders:
/// `[STATUS] DAY  TYPE  DISTANCE  PACE`
///
/// Four states: ok (cyan ✓), today (orange ●), future (dim ○), rest ("DESC").
enum WeekPlanRowState { ok, today, future, rest }

class FigmaWeekPlanRow extends StatelessWidget {
  const FigmaWeekPlanRow({
    super.key,
    required this.dayLabel,
    required this.state,
    this.type,
    this.distance,
    this.pace,
    this.onTap,
  });

  final String dayLabel;
  final WeekPlanRowState state;
  final String? type;
  final String? distance;
  final String? pace;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (state) {
      WeekPlanRowState.ok => FigmaColors.brandCyan,
      WeekPlanRowState.today => FigmaColors.brandOrange,
      WeekPlanRowState.future => FigmaColors.textSecondary,
      WeekPlanRowState.rest => FigmaColors.textMuted,
    };
    final iconWidget = switch (state) {
      WeekPlanRowState.ok => const Icon(Icons.check, size: 14, color: FigmaColors.brandCyan),
      WeekPlanRowState.today => const Icon(Icons.fiber_manual_record, size: 10, color: FigmaColors.brandOrange),
      WeekPlanRowState.future => const Icon(Icons.fiber_manual_record_outlined, size: 12, color: FigmaColors.textDim),
      WeekPlanRowState.rest => Text(
          'DESC',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textMuted,
          ),
        ),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13.718, vertical: 14),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            SizedBox(width: 34, child: Center(child: iconWidget)),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                dayLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  height: 16.5 / 11,
                  letterSpacing: 1.65,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                type ?? '',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 19.5 / 13,
                  fontWeight: FontWeight.w700,
                  color: state == WeekPlanRowState.rest
                      ? FigmaColors.textMuted
                      : FigmaColors.textPrimary,
                ),
              ),
            ),
            if (distance != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  distance!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    height: 19.5 / 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            if (pace != null)
              Text(
                pace!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  height: 16.5 / 11,
                  fontWeight: FontWeight.w400,
                  color: FigmaColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
