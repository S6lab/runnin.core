import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(RunninPalette palette) {
    final base = ThemeData.dark();

    final textTheme = GoogleFonts.jetBrainsMonoTextTheme(base.textTheme).apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.dark(
        surface: palette.surface,
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        error: palette.error,
      ),
      textTheme: textTheme,
      extensions: [RunninThemeTokens(palette: palette)],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: palette.text,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1.735),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: palette.primary),
        ),
        labelStyle: TextStyle(color: palette.muted),
        hintStyle: TextStyle(color: palette.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.background,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            textStyle: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.08,
              fontSize: 14,
            ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.border),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            textStyle: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
              fontSize: 14,
            ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  static ThemeData get dark => build(RunninSkin.cyber.palette);
}
