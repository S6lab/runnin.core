import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // Figma gap values (px)
  static const double xs = 3.985;   // gap-xs: ~4px
  static const double sm = 5.991;   // gap-sm: ~6px
  static const double md = 7.997;   // gap-md: ~8px
  static const double lg = 11.983;  // gap-lg: ~12px
  static const double xl = 15.995;  // gap-xl: ~16px
  static const double xxl = 23.992; // gap-section: ~24px

  static const double zero = 0;
  static const double px177 = 17.7;
  static const double px20 = 20;
}

abstract final class AppDimensions {
  // Figma design system: zero border-radius everywhere (except toggle pill)
  static const double borderRadius = 0;
  static const double borderRadiusPill = 999; // toggle pill only

  // Figma universal border width: 1.735px on all cards/rows/inputs
  static const double borderUniversal = 1.735;

  static const double shadowBlur = 10;
  static const double shadowOffset = 2;

  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 24;
  static const double iconXl = 32;

  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 80;

  // Button heights (Figma px values)
  static const double buttonHeightSm = 32.94;
  static const double buttonHeightMd = 38.71;
  static const double buttonHeightLg = 54.71;

  // Input heights (Figma px values)
  static const double inputHeightSm = 38.71;
  static const double inputHeightMd = 44.69;
  static const double inputHeightLg = 58.73;

  // Navigation heights
  static const double navbarHeight = 79;
}

/// Figma-canonical pixel dimensions. Use these for any new code targeting
/// the Figma design system (`docs/figma/DESIGN_SYSTEM.md`). Existing code
/// keeps using [AppDimensions] until migrated.
abstract final class FigmaDimensions {
  // Screen
  static const double screenPaddingH = 23.992;
  static const double contentWidth368 = 319.841;

  // Border
  static const double borderUniversal = 1.735;

  // Top nav (DESIGN_SYSTEM.md §4.4)
  static const double topNavNoBack = 54.708;
  static const double topNavWithBack = 73.712;

  // Bottom nav + RUN FAB
  static const double bottomNav = 78.591;
  static const double runFab = 55.982;
  static const double runFabRingOuter = 65.05;

  // Buttons
  static const double backButton = 39.987; // square
  static const double tabSelector3 = 41.424;
  static const double tabSelector4 = 39.933;
  static const double ctaFullwidthMin = 46.954;
  static const double ctaFullwidthMax = 56.5;

  // Cards
  static const double metricCard = 85.45;
  static const double zoneCard = 58.937;
  static const double badgeCardOneLine = 91.848;
  static const double deviceCardConnect = 223.303;

  // Toggle pill
  static const double togglePillW = 35.975;
  static const double togglePillH = 19.98;
  static const double togglePillThumb = 15.995;

  // Progress bar heights
  static const double progressBarOnboarding = 2;
  static const double progressBarPlan = 4;
  static const double progressBarThin = 3.985;
  static const double progressBarMed = 5.991;
  static const double progressBarThick = 7.997;
}

/// Figma border-radius policy.
///
/// DESIGN_SYSTEM.md §1: "Zero border-radius em todos os elementos (exceto
/// toggle pill)". Use these constants instead of inline `BorderRadius.zero`
/// or `BorderRadius.circular(...)` so the policy stays grep-able.
abstract final class FigmaBorderRadius {
  static const BorderRadius zero = BorderRadius.zero;
  static const BorderRadius togglePill = BorderRadius.all(Radius.circular(100));
}

abstract final class AppShadow {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: AppDimensions.shadowBlur,
          offset: Offset(0, AppDimensions.shadowOffset),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: AppDimensions.shadowBlur * 1.5,
          offset: Offset(0, AppDimensions.shadowOffset * 2),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: AppDimensions.shadowBlur * 2,
          offset: Offset(0, AppDimensions.shadowOffset * 3),
        ),
      ];

  static List<BoxShadow> get glowPrimary => [
        BoxShadow(
          color: Color(0xFF00FF87).withValues(alpha: 0.5),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];

  static List<BoxShadow> get glowSecondary => [
        BoxShadow(
          color: Color(0xFFFF6B35).withValues(alpha: 0.4),
          blurRadius: 15,
          spreadRadius: 2,
        ),
      ];
}
