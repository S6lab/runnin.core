import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Bullet item para DESTAQUES (Weekly Report Detail) com prefix `+` (positive)
/// ou `!` (alert). Per mockup tela 23 §DESTAQUES.
enum HighlightType { positive, alert }

class FigmaHighlightBullet extends StatelessWidget {
  const FigmaHighlightBullet({
    super.key,
    required this.type,
    required this.text,
  });

  final HighlightType type;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isAlert = type == HighlightType.alert;
    final color = isAlert ? FigmaColors.brandOrange : FigmaColors.brandCyan;
    final prefix = isAlert ? '!' : '+';
    final bgAlpha = isAlert ? 0.08 : 0.04;
    final borderAlpha = isAlert ? 0.35 : 0.20;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: borderAlpha), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefix,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 19.5 / 13,
                color: FigmaColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
