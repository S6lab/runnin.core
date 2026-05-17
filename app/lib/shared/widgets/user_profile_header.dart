import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';

class UserProfileHeader extends StatelessWidget {
  final String userName;
  final int levelNumber;
  final bool isPremium;
  final int totalRuns;
  final double totalDistanceKm;

  const UserProfileHeader({
    super.key,
    required this.userName,
    required this.levelNumber,
    this.isPremium = false,
    required this.totalRuns,
    required this.totalDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(17.7, 20, 17.7, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(userName: userName, palette: palette),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.48,
                        color: palette.text,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      _PremiumBadge(palette: palette),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nível $levelNumber · · ',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.48,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalRuns.toString().toUpperCase()} CORRIDAS · ${totalDistanceKm.toStringAsFixed(1)}km total',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.48,
                    color: palette.muted,
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

class _Avatar extends StatelessWidget {
  final String userName;
  final RunninPalette palette;

  const _Avatar({required this.userName, required this.palette});

  @override
  Widget build(BuildContext context) {
    final initial = userName.isNotEmpty ? userName.characters.first.toUpperCase() : 'R';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: palette.background,
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final RunninPalette palette;

  const _PremiumBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        'PREMIUM',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: palette.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
