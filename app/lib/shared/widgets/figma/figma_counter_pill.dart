import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaCounterPill extends StatelessWidget {
  const FigmaCounterPill({
    super.key,
    required this.value,
    required this.label,
    this.accent = FigmaColors.brandCyan,
    this.width = 80,
  });

  final Object value; // int or String
  final String label;
  final Color accent;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 1),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1.0,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
