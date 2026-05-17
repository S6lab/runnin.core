import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Single stat tile used in the post-run report 3-column grid per
/// `docs/figma/screens/RUN_JOURNEY.md`: label + colored value + unit.
class FigmaPostRunStatCard extends StatelessWidget {
  const FigmaPostRunStatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = FigmaColors.brandCyan,
  });

  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13.718),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              height: 15 / 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      height: 15 / 10,
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
