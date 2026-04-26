import 'package:flutter/material.dart';

@immutable
class RunninPalette {
  final String id;
  final String label;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color success;
  final Color warning;
  final Color error;

  const RunninPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.success,
    required this.warning,
    required this.error,
  });

  List<Color> get previewBars => [primary, secondary, tertiary];
}

enum RunninSkin {
  artico,
  magenta,
  sangue,
  volt;

  RunninPalette get palette {
    switch (this) {
      case RunninSkin.artico:
        return const RunninPalette(
          id: 'artico',
          label: 'Artico',
          background: Color(0xFF060814),
          surface: Color(0xFF0C1220),
          surfaceAlt: Color(0xFF10192A),
          border: Color(0xFF1B2638),
          text: Color(0xFFF5F7FB),
          muted: Color(0xFF8C97AD),
          primary: Color(0xFF2ECDF3),
          secondary: Color(0xFFFF6E40),
          tertiary: Color(0xFF4D7DFF),
          success: Color(0xFF25C56B),
          warning: Color(0xFFF3BF31),
          error: Color(0xFFFF4D5A),
        );
      case RunninSkin.magenta:
        return const RunninPalette(
          id: 'magenta',
          label: 'Magenta',
          background: Color(0xFF080511),
          surface: Color(0xFF130C1E),
          surfaceAlt: Color(0xFF1A1028),
          border: Color(0xFF311642),
          text: Color(0xFFF8F5FF),
          muted: Color(0xFFA893BF),
          primary: Color(0xFFFF0E7A),
          secondary: Color(0xFF2CE0F0),
          tertiary: Color(0xFF8A56FF),
          success: Color(0xFF3BD47A),
          warning: Color(0xFFFFB800),
          error: Color(0xFFFF5574),
        );
      case RunninSkin.sangue:
        return const RunninPalette(
          id: 'sangue',
          label: 'Sangue',
          background: Color(0xFF0A0509),
          surface: Color(0xFF180B12),
          surfaceAlt: Color(0xFF211018),
          border: Color(0xFF3A1826),
          text: Color(0xFFF9F3F5),
          muted: Color(0xFFB89AA7),
          primary: Color(0xFFFF3B46),
          secondary: Color(0xFF66B5FF),
          tertiary: Color(0xFFFF7B56),
          success: Color(0xFF35C46F),
          warning: Color(0xFFFFB23D),
          error: Color(0xFFFF3B46),
        );
      case RunninSkin.volt:
        return const RunninPalette(
          id: 'volt',
          label: 'Volt',
          background: Color(0xFF070A10),
          surface: Color(0xFF10131B),
          surfaceAlt: Color(0xFF141A24),
          border: Color(0xFF262E3A),
          text: Color(0xFFF4F8F2),
          muted: Color(0xFF9DA4AF),
          primary: Color(0xFFD7FF3C),
          secondary: Color(0xFF8B66FF),
          tertiary: Color(0xFF39D5FF),
          success: Color(0xFF32D17C),
          warning: Color(0xFFFFC93C),
          error: Color(0xFFFF5B66),
        );
    }
  }
}

@immutable
class RunninThemeTokens extends ThemeExtension<RunninThemeTokens> {
  final RunninPalette palette;

  const RunninThemeTokens({required this.palette});

  @override
  RunninThemeTokens copyWith({RunninPalette? palette}) {
    return RunninThemeTokens(palette: palette ?? this.palette);
  }

  @override
  RunninThemeTokens lerp(
    covariant ThemeExtension<RunninThemeTokens>? other,
    double t,
  ) {
    if (other is! RunninThemeTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension RunninThemeContext on BuildContext {
  RunninPalette get runninPalette {
    final tokens = Theme.of(this).extension<RunninThemeTokens>();
    return tokens?.palette ?? RunninSkin.artico.palette;
  }
}
