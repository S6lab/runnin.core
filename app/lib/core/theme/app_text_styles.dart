import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  final TextStyle displayLg;
  final TextStyle displayMd;
  final TextStyle displaySm;

  final TextStyle dataXl;
  final TextStyle dataMd;
  final TextStyle dataSm;

  final TextStyle bodyMd;
  final TextStyle bodySm;

  final TextStyle labelCaps;
  final TextStyle labelMd;

  const AppTextStyles({
    required this.displayLg,
    required this.displayMd,
    required this.displaySm,
    required this.dataXl,
    required this.dataMd,
    required this.dataSm,
    required this.bodyMd,
    required this.bodySm,
    required this.labelCaps,
    required this.labelMd,
  });

  static AppTextStyles build(Color textColor, Color mutedColor) {
    return AppTextStyles(
      displayLg: GoogleFonts.jetBrainsMono(
        fontSize: 52,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.0,
        color: textColor,
      ),
      displayMd: GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.1,
        color: textColor,
      ),
      displaySm: GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        height: 1.2,
        color: textColor,
      ),
      dataXl: GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.0,
        color: textColor,
      ),
      dataMd: GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.0,
        color: textColor,
      ),
      dataSm: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        height: 1.2,
        color: textColor,
      ),
      bodyMd: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.5,
        color: textColor,
      ),
      bodySm: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.4,
        color: mutedColor,
      ),
      labelCaps: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.12,
        height: 1.2,
        color: mutedColor,
      ),
      labelMd: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04,
        height: 1.3,
        color: textColor,
      ),
    );
  }

  static AppTextStyles get defaultStyles {
    return build(AppColors.text, AppColors.muted);
  }
}
