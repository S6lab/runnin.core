import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Single metric cell for the active-run 2×2 HUD grid per
/// `docs/figma/screens/RUN_JOURNEY.md`. Label + optional cyan superscript
/// index + big 28 px value + optional unit suffix.
class FigmaRunMetricCell extends StatelessWidget {
  const FigmaRunMetricCell({
    super.key,
    required this.label,
    required this.value,
    this.index,
    this.unit,
    this.valueColor = FigmaColors.textPrimary,
  });

  final String label;
  final String value;
  final String? index;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 16.5 / 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textSecondary,
              ),
            ),
            if (index != null) ...[
              const SizedBox(width: 4),
              Text(
                index!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  height: 13.5 / 9,
                  fontWeight: FontWeight.w400,
                  color: FigmaColors.brandCyan,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 16.5 / 11,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
