import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double _base = 4;

  static double get xs => _base * 0.5;
  dynamic get sm => _base * 1;
  dynamic get md => _base * 1.5;
  dynamic get lg => _base * 2;
  dynamic get xl => _base * 3;
  dynamic get xxl => _base * 4;
  dynamic get xxxl => _base * 6;
  dynamic get huge => _base * 8;

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

  static const double buttonHeightSm = 36;
  static const double buttonHeightMd = 48;
  static const double buttonHeightLg = 56;
  static const double buttonHeightXl = 79;

  static const double inputHeightSm = 40;
  static const double inputHeightMd = 48;
  static const double inputHeightLg = 56;

  static const double navbarHeight = 79;
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
