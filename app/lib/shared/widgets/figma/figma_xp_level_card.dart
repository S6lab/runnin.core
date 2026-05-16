import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// XP/Level card per `docs/figma/screens/PERFIL.md` §GAMIFICAÇÃO > XP.
/// Big 56 px level number + label + XP fraction + thick 7.997 px progress bar.
class FigmaXpLevelCard extends StatelessWidget {
  const FigmaXpLevelCard({
    super.key,
    required this.level,
    required this.levelLabel,
    required this.currentXp,
    required this.nextLevelXp,
  });

  final int level;
  final String levelLabel; // e.g. "Corredor"
  final int currentXp;
  final int nextLevelXp;

  @override
  Widget build(BuildContext context) {
    final progress = nextLevelXp == 0 ? 0.0 : (currentXp / nextLevelXp).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(21.715),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$level',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 56,
                  height: 50.4 / 56,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.brandCyan,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  levelLabel.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 16.5 / 11,
                    letterSpacing: 1.65,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currentXp / $nextLevelXp XP',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 19.5 / 13,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 7.997,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: FigmaColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(FigmaColors.brandCyan),
            ),
          ),
        ],
      ),
    );
  }
}
