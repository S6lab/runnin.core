import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(RunninPalette palette) {
    final base = ThemeData.dark();
    final textTheme = base.textTheme.apply(
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
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.background,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark => build(RunninSkin.artico.palette);
}
