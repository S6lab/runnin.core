import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Horizontal split row used in the post-run report per
/// `docs/figma/screens/RUN_JOURNEY.md`: KM label + relative time bar +
/// formatted time. Best split renders cyan; others render dim.
class FigmaSplitRow extends StatelessWidget {
  const FigmaSplitRow({
    super.key,
    required this.kmLabel,
    required this.time,
    required this.barRatio, // 0.0–1.0
    this.isBest = false,
  });

  final String kmLabel;
  final String time;
  final double barRatio;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final barColor = isBest ? FigmaColors.brandCyan : FigmaColors.textDim;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            kmLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: FigmaColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                color: FigmaColors.progressTrack,
              ),
              FractionallySizedBox(
                widthFactor: barRatio.clamp(0.0, 1.0),
                child: Container(height: 8, color: barColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            time,
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 19.5 / 13,
              fontWeight: FontWeight.w500,
              color: isBest ? FigmaColors.brandCyan : FigmaColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
