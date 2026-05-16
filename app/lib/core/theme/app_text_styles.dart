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

  // Figma typography styles (JetBrains Mono)
  final TextStyle figmaDisplayLevel;
  final TextStyle figmaDisplayHero;
  final TextStyle figmaDisplayBrand;
  final TextStyle figmaDisplayHeading;
  final TextStyle figmaHeadingSection;
  final TextStyle figmaSectionIndex;
  final TextStyle figmaHeadingApp;
  final TextStyle figmaHeadingStat;
  final TextStyle figmaHeadingPostRun;
  final TextStyle figmaLabelBadge;
  final TextStyle figmaLabelSlide;
  final TextStyle figmaLabelAssessment;
  final TextStyle figmaLabelTagline;
  final TextStyle figmaLabelSlideNumber;
  final TextStyle figmaLabelNav;
  final TextStyle figmaLabelSkip;
  final TextStyle figmaLabelField;
  final TextStyle figmaLabelMetric;
  final TextStyle figmaBodyMain;
  final TextStyle figmaBodyAssessment;
  final TextStyle figmaBodyApp;
  final TextStyle figmaBodySmall;
  final TextStyle figmaBodyTiny;
  final TextStyle figmaBodyMicro;
  final TextStyle figmaCardTitle;
  final TextStyle figmaCardDescription;
  final TextStyle figmaCtaButton;
  final TextStyle figmaCtaTab;
  final TextStyle figmaCtaTabSmall;
  final TextStyle figmaHeaderLogo;
  final TextStyle figmaHeaderBreadcrumb;
  final TextStyle figmaNavBottombar;
  final TextStyle figmaNavRunFab;
  final TextStyle figmaBadgePremium;
  final TextStyle figmaBadgeDot;
  final TextStyle figmaBadgePriority;

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
    required this.figmaDisplayLevel,
    required this.figmaDisplayHero,
    required this.figmaDisplayBrand,
    required this.figmaDisplayHeading,
    required this.figmaHeadingSection,
    required this.figmaSectionIndex,
    required this.figmaHeadingApp,
    required this.figmaHeadingStat,
    required this.figmaHeadingPostRun,
    required this.figmaLabelBadge,
    required this.figmaLabelSlide,
    required this.figmaLabelAssessment,
    required this.figmaLabelTagline,
    required this.figmaLabelSlideNumber,
    required this.figmaLabelNav,
    required this.figmaLabelSkip,
    required this.figmaLabelField,
    required this.figmaLabelMetric,
    required this.figmaBodyMain,
    required this.figmaBodyAssessment,
    required this.figmaBodyApp,
    required this.figmaBodySmall,
    required this.figmaBodyTiny,
    required this.figmaBodyMicro,
    required this.figmaCardTitle,
    required this.figmaCardDescription,
    required this.figmaCtaButton,
    required this.figmaCtaTab,
    required this.figmaCtaTabSmall,
    required this.figmaHeaderLogo,
    required this.figmaHeaderBreadcrumb,
    required this.figmaNavBottombar,
    required this.figmaNavRunFab,
    required this.figmaBadgePremium,
    required this.figmaBadgeDot,
    required this.figmaBadgePriority,
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
      // Figma typography styles
      figmaDisplayLevel: GoogleFonts.jetBrainsMono(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 50.4 / 56,
        color: textColor,
      ),
      figmaDisplayHero: GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      figmaDisplayBrand: GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 42 / 28,
        letterSpacing: 3.36,
        color: textColor,
      ),
      figmaDisplayHeading: GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 28 / 28,
        letterSpacing: -0.84,
        color: textColor,
      ),
      figmaHeadingSection: GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 24 / 24,
        letterSpacing: -0.48,
        color: textColor,
      ),
      figmaSectionIndex: GoogleFonts.jetBrainsMono(
        fontSize: 6.6,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      figmaHeadingApp: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 24.2 / 22,
        letterSpacing: -0.44,
        color: textColor,
      ),
      figmaHeadingStat: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 24.2 / 22,
        color: textColor,
      ),
      figmaHeadingPostRun: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      figmaLabelBadge: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 18 / 12,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaLabelSlide: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        letterSpacing: 1.8,
        color: textColor,
      ),
      figmaLabelAssessment: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 19.5 / 13,
        letterSpacing: 1.95,
        color: textColor,
      ),
      figmaLabelTagline: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        letterSpacing: 2.4,
        color: textColor,
      ),
      figmaLabelSlideNumber: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 14 / 14,
        letterSpacing: -0.84,
        color: textColor,
      ),
      figmaLabelNav: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 21 / 14,
        letterSpacing: 1.12,
        color: textColor,
      ),
      figmaLabelSkip: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 19.5 / 13,
        letterSpacing: 1.3,
        color: textColor,
      ),
      figmaLabelField: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16.5 / 11,
        letterSpacing: 1.65,
        color: mutedColor,
      ),
      figmaLabelMetric: GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w400,
        height: 13.5 / 9,
        letterSpacing: 0.9,
        color: textColor,
      ),
      figmaBodyMain: GoogleFonts.jetBrainsMono(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 25.5 / 15,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaBodyAssessment: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 23.8 / 14,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaBodyApp: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 19.5 / 13,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaBodySmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaBodyTiny: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 16.5 / 11,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaBodyMicro: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 15 / 10,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaCardTitle: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 19.5 / 13,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaCardDescription: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        letterSpacing: 0,
        color: textColor,
      ),
      figmaCtaButton: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 18 / 12,
        letterSpacing: 1.2,
        color: textColor,
      ),
      figmaCtaTab: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 18 / 12,
        letterSpacing: 1.2,
        color: textColor,
      ),
      figmaCtaTabSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 16.5 / 11,
        letterSpacing: 0.66,
        color: textColor,
      ),
      figmaHeaderLogo: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 21 / 14,
        letterSpacing: 1.4,
        color: textColor,
      ),
      figmaHeaderBreadcrumb: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 19.5 / 13,
        letterSpacing: 1.3,
        color: textColor,
      ),
      figmaNavBottombar: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 15 / 10,
        letterSpacing: 1,
        color: textColor,
      ),
      figmaNavRunFab: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 16.5 / 11,
        letterSpacing: 1.1,
        color: textColor,
      ),
      figmaBadgePremium: GoogleFonts.jetBrainsMono(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        height: 12 / 8,
        color: textColor,
      ),
      figmaBadgeDot: GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        height: 13.5 / 9,
        color: textColor,
      ),
      figmaBadgePriority: GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        height: 13.5 / 9,
        color: textColor,
      ),
    );
  }

  static AppTextStyles get defaultStyles {
    return build(AppColors.text, AppColors.muted);
  }
}

