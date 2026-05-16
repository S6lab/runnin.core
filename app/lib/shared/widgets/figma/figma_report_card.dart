import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Report list card in TREINO §Relatórios per `docs/figma/screens/TREINO.md`
/// tela 3: header (date + week label) + 4 stat tiles (ADERÊNCIA / KM /
/// SESSÕES / FREE) + clipped coach summary preview.
class FigmaReportCard extends StatelessWidget {
  const FigmaReportCard({
    super.key,
    required this.dateLabel,
    required this.weekLabel,
    required this.adherencePct,
    required this.km,
    required this.sessions,
    required this.freeRuns,
    required this.coachPreview,
    this.onTap,
  });

  final String dateLabel; // e.g. "03–09 MAR"
  final String weekLabel; // e.g. "SEM 02"
  final int adherencePct;
  final double km;
  final int sessions;
  final int freeRuns;
  final String coachPreview;
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
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dateLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.brandCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  weekLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('ADERÊNCIA', '$adherencePct%', FigmaColors.brandCyan),
                _stat('KM', km.toStringAsFixed(1), FigmaColors.textPrimary),
                _stat('SESSÕES', '$sessions', FigmaColors.textPrimary),
                _stat('FREE', '$freeRuns', FigmaColors.brandOrange),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0x08FF6B35),
                border: Border(
                  left: BorderSide(color: FigmaColors.brandOrange, width: 1.041),
                ),
              ),
              child: Text(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              height: 22 / 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
