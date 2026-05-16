import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// HIST 2-col stat card per `docs/figma/screens/HIST.md` tela 1
/// (Dados — Tendências 3 Meses). Label + big colored value + optional
/// delta with arrow indicator (↑/↓).
class FigmaHistStatCard extends StatelessWidget {
  const FigmaHistStatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaIsPositive = true,
    this.valueColor = FigmaColors.textPrimary,
  });

  final String label;
  final String value;
  final String? unit;
  final String? delta;
  final bool deltaIsPositive;
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
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  deltaIsPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 11,
                  color: deltaIsPositive ? FigmaColors.brandCyan : FigmaColors.zone5,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: deltaIsPositive ? FigmaColors.brandCyan : FigmaColors.zone5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
