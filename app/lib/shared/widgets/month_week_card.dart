import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Card-per-week in TREINO §Plano Mensal per `docs/figma/screens/TREINO.md`
/// tela 2: header (semana + foco), volume label + km, status pill, and a
/// short volume progress bar.
class MonthWeekCard extends StatelessWidget {
  const MonthWeekCard({
    super.key,
    required this.weekLabel,
    required this.focus,
    required this.volumeKm,
    required this.targetKm,
    required this.statusLabel,
    this.statusColor = FigmaColors.brandCyan,
  });

  final String weekLabel;
  final String focus;
  final double volumeKm;
  final double targetKm;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final progress = targetKm <= 0 ? 0.0 : (volumeKm / targetKm).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(13.718),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        border: Border.all(color: palette.border, width: 1.735),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    weekLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      letterSpacing: 1.65,
                      fontWeight: FontWeight.w500,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    focus,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w400,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: statusColor.withValues(alpha: 0.14),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${volumeKm.toStringAsFixed(1)} / ${targetKm.toStringAsFixed(1)} km',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 19.5 / 13,
              fontWeight: FontWeight.w400,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 5.991,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: palette.track,
              valueColor: const AlwaysStoppedAnimation(palette.primary),
            ),
          ),
        ],
      ),
    );
  }
}
