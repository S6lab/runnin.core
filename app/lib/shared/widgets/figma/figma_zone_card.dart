import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Per-zone card for PERFIL > SAÚDE > ZONAS per `docs/figma/screens/PERFIL.md`.
/// Shows zone color swatch, label (e.g. "Z1 — Recuperação"), BPM range,
/// % of time, and a thick 7.997 px progress bar.
class FigmaZoneCard extends StatelessWidget {
  const FigmaZoneCard({
    super.key,
    required this.zoneNumber,
    required this.zoneLabel,
    required this.bpmRange,
    required this.percent,
    required this.zoneColor,
  });

  final int zoneNumber; // 1..5
  final String zoneLabel; // e.g. "Recuperação"
  final String bpmRange; // e.g. "98-118"
  final double percent; // 0..100
  final Color zoneColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58.937,
      padding: const EdgeInsets.symmetric(horizontal: 13.718, vertical: 10),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            color: zoneColor,
            child: Text(
              'Z$zoneNumber',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FigmaColors.bgBase,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  zoneLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    height: 19.5 / 13,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bpmRange bpm',
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
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: zoneColor,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 7.997,
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: FigmaColors.progressTrack,
                    valueColor: AlwaysStoppedAnimation(zoneColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
