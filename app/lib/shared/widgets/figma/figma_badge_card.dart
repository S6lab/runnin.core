import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Badge card for the Gamification grid per `docs/figma/screens/PERFIL.md`
/// §GAMIFICAÇÃO > BADGES. Locked badges fade to opacity 50% and render an
/// inline progress bar; unlocked badges show full color + check mark.
class FigmaBadgeCard extends StatelessWidget {
  const FigmaBadgeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.progress = 0.0, // 0.0–1.0, ignored when unlocked
    this.accent = FigmaColors.brandCyan,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = unlocked ? const Color(0x0800D4FF) : FigmaColors.surfaceCard;
    final border = unlocked ? const Color(0x3000D4FF) : FigmaColors.borderDefault;
    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: Container(
        height: 91.848,
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      height: 19.5 / 13,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textPrimary,
                    ),
                  ),
                ),
                if (unlocked)
                  const Icon(Icons.check, size: 16, color: FigmaColors.brandCyan),
              ],
            ),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 16.5 / 11,
                fontWeight: FontWeight.w400,
                color: FigmaColors.textSecondary,
              ),
            ),
            if (!unlocked)
              SizedBox(
                height: 3.985,
                child: ClipRRect(
                  borderRadius: FigmaBorderRadius.zero,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: FigmaColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation(FigmaColors.brandCyan),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
