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

  // Figma universal border width: 1.041px on all cards/rows/inputs
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

/// Figma color tokens (DESIGN_SYSTEM.md §2).
abstract final class FigmaColors {
  // --- Background ---
  static const Color bgBase = Color(0xFF050510);

  // --- Brand ---
  static const Color brandCyan = Color(0xFF00D4FF);
  static const Color brandOrange = Color(0xFFFF6B35);
  static const Color brandGreen = Color(0xFF22C55E);

  // --- Text ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x8CFFFFFF); // rgba(255,255,255,0.55)
  static const Color textMuted = Color(0x73FFFFFF); // rgba(255,255,255,0.45)
  static const Color textDim = Color(0x4DFFFFFF); // rgba(255,255,255,0.30)
  static const Color textGhost = Color(0x33FFFFFF); // rgba(255,255,255,0.20)
  static const Color textSeparator = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const Color textPlaceholder = Color(0x7FFFFFFF); // rgba(255,255,255,0.50)

  // --- Surface ---
  static const Color surfaceCard = Color(0x08FFFFFF); // rgba(255,255,255,0.03)
  static const Color surfaceCardCyan = Color(0x0800D4FF); // rgba(0,212,255,0.03)
  static const Color surfaceCardOrange = Color(0x08FF6B35); // rgba(255,107,53,0.03)
  static const Color surfaceInput = Color(0x08FFFFFF); // rgba(255,255,255,0.03)

  // --- Border ---
  static const Color borderDefault = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color borderCyan = Color(0x2400D4FF); // rgba(0,212,255,0.14)
  static const Color borderCyanStrong = Color(0x3000D4FF); // rgba(0,212,255,0.19)
  static const Color borderCyanActive = Color(0xFF00D4FF);
  static const Color borderOrange = Color(0xFFFF6B35);
  static const Color borderInput = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color borderBackBtn = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const Color borderUploadDashed = Color(0x4F00D4FF); // rgba(0,212,255,0.31)

  // --- Navigation ---
  static const Color navTopbarBg = Color(0xE9050510); // rgba(5,5,16,0.92)
  static const Color navBottombarBg = Color(0xF5050510); // rgba(5,5,16,0.96)
  static const Color navBorder = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color navRunShadow = Color(0x4F00D4FF); // rgba(0,212,255,0.31)

  // --- Progress ---
  static const Color progressTrack = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color progressFill = Color(0xFF00D4FF);

  // --- Zones ---
  static const Color zone1 = Color(0xFF3B82F6);
  static const Color zone2 = Color(0xFF22C55E);
  static const Color zone3 = Color(0xFFEAB308);
  static const Color zone4 = Color(0xFFF97316);
  static const Color zone5 = Color(0xFFEF4444);

  // --- Skin Palettes ---
  static const Color skinSanguinePrimary = Color(0xFFFF2D2D);
  static const Color skinSanguineSecondary = Color(0x4EA8FFFF); // rgba(78,168,255,1.0)
  static const Color skinMagentaPrimary = Color(0xFFFF0066);
  static const Color skinMagentaSecondary = Color(0x00E5FFFF); // rgba(0,229,255,1.0)
  static const Color skinVoltPrimary = Color(0xFFCCFF00);
  static const Color skinVoltSecondary = Color(0x8B5CF6FF); // rgba(139,92,246,1.0)
  static const Color skinArcticPrimary = Color(0xFF00D4FF);
  static const Color skinArcticSecondary = Color(0xFFFF6B35);

  // --- Interactive States ---
  static const Color selectionActiveBg = Color(0x1900D4FF);
  static const Color selectionActiveBorder = Color(0x4D00D4FF);
  static const Color infoBg = Color(0x2400D4FF);
  static const Color skinActiveBg = Color(0x0F00D4FF);
  static const Color dotActive = Color(0xFF00D4FF);
  static const Color dotVisited = Color(0x33FFFFFF);
  static const Color dotInactive = Color(0x0FFFFFFF);
}
