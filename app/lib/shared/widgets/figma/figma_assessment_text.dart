import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaAssessmentLabel extends StatelessWidget {
  final String text;

  const FigmaAssessmentLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 19.5 / 13,
        letterSpacing: 1.95,
        color: FigmaColors.brandCyan,
      ),
    );
  }
}

class FigmaAssessmentHeading extends StatelessWidget {
  final String text;

  const FigmaAssessmentHeading({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 26.4 / 24,
        letterSpacing: -0.48,
        color: FigmaColors.textPrimary,
      ),
    );
  }
}

class FigmaAssessmentDescription extends StatelessWidget {
  final String text;

  const FigmaAssessmentDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 20.8 / 13,
        letterSpacing: 0,
        color: FigmaColors.textSecondary,
      ),
    );
  }
}
