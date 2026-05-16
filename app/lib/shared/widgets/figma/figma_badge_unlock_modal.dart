import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Modal overlay shown when a badge is unlocked post-run per
/// `docs/figma/screens/RUN_JOURNEY.md` §Badge Unlock Modal.
/// Dark overlay + centered card with concentric cyan rings around the
/// badge icon + XP gain text.
///
/// Call via `showDialog(context: ctx, builder: (_) => FigmaBadgeUnlockModal(...))`.
class FigmaBadgeUnlockModal extends StatelessWidget {
  const FigmaBadgeUnlockModal({
    super.key,
    required this.badgeIcon,
    required this.badgeTitle,
    required this.xpGained,
    this.message,
    this.onDismiss,
  });

  final IconData badgeIcon;
  final String badgeTitle;
  final int xpGained;
  final String? message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: const RoundedRectangleBorder(borderRadius: FigmaBorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: FigmaColors.bgBase,
          border: Border.all(color: FigmaColors.brandCyan, width: 1.735),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BADGE DESBLOQUEADA',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 15 / 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: FigmaColors.brandCyan,
              ),
            ),
            const SizedBox(height: 20),
            _RingedIcon(icon: badgeIcon),
            const SizedBox(height: 20),
            Text(
              badgeTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                height: 24.2 / 22,
                letterSpacing: -0.44,
                fontWeight: FontWeight.w700,
                color: FigmaColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 19.5 / 13,
                  fontWeight: FontWeight.w400,
                  color: FigmaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '+$xpGained XP',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 28,
                height: 28 / 28,
                fontWeight: FontWeight.w700,
                color: FigmaColors.brandOrange,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDismiss ?? () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 49.982,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: FigmaColors.brandCyan,
                  borderRadius: FigmaBorderRadius.zero,
                ),
                child: Text(
                  'CONTINUAR  ↗',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    height: 18 / 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.bgBase,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingedIcon extends StatelessWidget {
  const _RingedIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final size in [120.0, 100.0, 80.0])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FigmaColors.brandCyan.withValues(alpha: size / 150),
                  width: 1.5,
                ),
              ),
            ),
          Icon(icon, size: 40, color: FigmaColors.brandCyan),
        ],
      ),
    );
  }
}
