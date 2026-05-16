import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Coach.AI notification card per `docs/figma/screens/HOME.md` §02
/// (lines 74–91). Five colored variants (cyan / yellow / blue / orange /
/// purple) sharing layout: icon + title + subtitle + timestamp + caret.
///
/// Pixel-perfect Figma values inlined (sizes, line-heights, weights) so
/// the component renders identically regardless of theme overrides.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.borderColor,
    this.timestamp,
    this.expandable = true,
    this.onTap,
  });

  /// Leading icon (18×18 px), tinted with [borderColor].
  final IconData icon;

  /// Bold 11 px title, color = [borderColor]. Caller controls casing.
  final String title;

  /// Medium 11 px subtitle, ellipsized to one line.
  final String subtitle;

  /// Optional Medium 9 px timestamp shown top-right (e.g. "AGORA", "05:30").
  final String? timestamp;

  /// 1.735 px solid border. One of the five HOME §02 accent colors.
  final Color borderColor;

  /// When true (default), shows the ▼ caret indicating expansion.
  final bool expandable;

  /// Tap handler for the whole card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 62.444,
        padding: const EdgeInsets.fromLTRB(17.74, 12, 16, 12),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard, // rgba(255,255,255,0.03)
          border: Border.all(color: borderColor, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: borderColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      height: 16.5 / 11,
                      fontWeight: FontWeight.w700,
                      color: borderColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      height: 16.5 / 11,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      height: 13.5 / 9,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textSecondary,
                    ),
                  ),
                  if (expandable)
                    Text(
                      '▼',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        height: 1,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Canonical accent colors for the 5 HOME §02 notification variants.
abstract final class NotificationAccent {
  /// Cyan — "MELHOR HORÁRIO" (timing).
  static const Color cyan = Color(0xFF00D4FF);

  /// Yellow — "PREPARO NUTRICIONAL".
  static const Color yellow = Color(0xFFEAB308);

  /// Blue — "HIDRATAÇÃO".
  static const Color blue = Color(0xFF3B82F6);

  /// Orange — "CHECKLIST PRÉ-EASY RUN".
  static const Color orange = Color(0xFFFF6B35);

  /// Purple — "SONO → PERFORMANCE".
  static const Color purple = Color(0xFF8B5CF6);
}
