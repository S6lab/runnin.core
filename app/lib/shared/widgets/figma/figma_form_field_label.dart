import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaFormFieldLabel extends StatelessWidget {
  final String text;

  const FigmaFormFieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16.5 / 11,
        letterSpacing: 1.65,
        color: FigmaColors.textSecondary,
      ),
    );
  }
}
