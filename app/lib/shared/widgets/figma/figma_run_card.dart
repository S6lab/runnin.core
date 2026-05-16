import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Run list card in HIST §Corridas per `docs/figma/screens/HIST.md` tela 2.
/// Type badge (40px circle) + 3-stat row (distância / pace / tempo) + clipped
/// coach preview text.
class FigmaRunCard extends StatelessWidget {
  const FigmaRunCard({
    super.key,
    required this.typeLabel,
    required this.dateLabel,
    required this.distanceKm,
    required this.pace,
    required this.duration,
    required this.coachPreview,
    this.typeAccent = FigmaColors.brandCyan,
    this.onTap,
  });

  final String typeLabel; // e.g. "EASY"
  final String dateLabel;
  final double distanceKm;
  final String pace;
  final String duration;
  final String coachPreview;
  final Color typeAccent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: typeAccent.withValues(alpha: 0.14),
                    border: Border.all(color: typeAccent, width: 1.735),
                  ),
                  child: Text(
                    typeLabel.substring(0, 1),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: typeAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      typeLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        height: 19.5 / 13,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.textPrimary,
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        height: 15 / 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('${distanceKm.toStringAsFixed(1)}K', 'DIST'),
                _stat(pace, 'PACE'),
                _stat(duration, 'TEMPO'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              coachPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w400,
                color: FigmaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w700,
              color: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
