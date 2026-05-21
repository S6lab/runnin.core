import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Cores semânticas de zona cardíaca — independentes de skin
abstract final class HeartZoneColors {
  static const z1 = Color(0xFF4D7DFF); // Leve < 120bpm
  static const z2 = Color(0xFF25C56B); // Moderado 120-140bpm
  static const z3 = Color(0xFFF3BF31); // Aeróbico 140-160bpm
  static const z4 = Color(0xFFFF6E40); // Limiar 160-175bpm
  static const z5 = Color(0xFFFF3B46); // Máximo > 175bpm

  static Color forZone(int zone) => switch (zone) {
    1 => z1,
    2 => z2,
    3 => z3,
    4 => z4,
    _ => z5,
  };
}

// Cores de notificação (HOME.md Section 02)
abstract final class NotificationColors {
  static const notification1 = Color(0xFF00D4FF); // MELHOR HORÁRIO
  static const notification2 = Color(0xFFEAB308); // PREPARO NUTRICIONAL
  static const notification3 = Color(0xFF3B82F6); // HIDRATAÇÃO
  static const notification4 = Color(0xFFFF6B35); // CHECKLIST PRÉ-EASY RUN
  static const notification5 = Color(0xFF8B5CF6); // SONO → PERFORMANCE
}

@immutable
class RunninTypography {
  // Display — headers de seção, títulos de página (all-caps, peso alto)
  final TextStyle displayLg;
  final TextStyle displayMd;
  final TextStyle displaySm;

  // Data — pace, distância, BPM (monospace/tabular)
  final TextStyle dataXl;
  final TextStyle dataMd;
  final TextStyle dataSm;
  /// Data secundário (22px, w500) — pra _BigHeading da home (SEMANA,
  /// PERFORMANCE, etc). Antes só existia em AppTextStyles; promovido
  /// pra cá pra ser usado universalmente via context.runninType.
  final TextStyle dataXs;

  // Body — textos narrativos do Coach, descrições
  final TextStyle bodyMd;
  final TextStyle bodySm;
  /// Body compacto (11px, w400) — pra captions, sub-labels, timestamps.
  /// Antes só existia em AppTextStyles.
  final TextStyle bodyXs;

  // Label — microcopy, tags, nav labels
  final TextStyle labelCaps;
  final TextStyle labelMd;

  const RunninTypography({
    required this.displayLg,
    required this.displayMd,
    required this.displaySm,
    required this.dataXl,
    required this.dataMd,
    required this.dataSm,
    required this.dataXs,
    required this.bodyMd,
    required this.bodySm,
    required this.bodyXs,
    required this.labelCaps,
    required this.labelMd,
  });

  static RunninTypography build(Color textColor, Color mutedColor) {
    return RunninTypography(
      displayLg: GoogleFonts.jetBrainsMono(
        fontSize: 52,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        height: 1.0,
        color: textColor,
      ),
      displayMd: GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.1,
        color: textColor,
      ),
      displaySm: GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        height: 1.2,
        color: textColor,
      ),
      dataXl: GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w500,
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
      dataXs: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.44,
        height: 1.1,
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
      bodyXs: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.4,
        color: mutedColor,
      ),
      labelCaps: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
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
}

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

// Fundo de card NEUTRO (cinza/preto) — igual em todas as skins, pra não ter
// "película" tingida. As cores de skin (primary/secondary/text/border) seguem
// por skin; só o preenchimento de card (surface/surfaceAlt) é padronizado.
const Color _kCardSurface = Color(0xFF0E0E12);
const Color _kCardSurfaceAlt = Color(0xFF15151A);

enum RunninSkin {
  artico,
  magenta,
  volt,
  matrix;

  RunninPalette get palette {
    switch (this) {
      case RunninSkin.artico:
        return const RunninPalette(
          id: 'artico',
          label: 'Artico',
          background: Color(0xFF060814),
          surface: _kCardSurface,
          surfaceAlt: _kCardSurfaceAlt,
          border: Color(0xFF1A1D28),
          text: Color(0xFFF5F7FB),
          muted: Color(0xFF8C97AD),
          // Alinhado aos hex de FigmaColors.brandCyan/brandOrange (dominantes no
          // app) pra o skin artico ficar idêntico após a migração brand->palette.
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFFFF6B35),
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
          surface: _kCardSurface,
          surfaceAlt: _kCardSurfaceAlt,
          border: Color(0xFF1F1A28),
          text: Color(0xFFF8F5FF),
          muted: Color(0xFFA893BF),
          primary: Color(0xFFFF0E7A),
          secondary: Color(0xFF2CE0F0),
          tertiary: Color(0xFF8A56FF),
          success: Color(0xFF3BD47A),
          warning: Color(0xFFFFB800),
          error: Color(0xFFFF5574),
        );
      case RunninSkin.volt:
        return const RunninPalette(
          id: 'volt',
          label: 'Volt',
          background: Color(0xFF070A10),
          surface: _kCardSurface,
          surfaceAlt: _kCardSurfaceAlt,
          border: Color(0xFF1B1E26),
          text: Color(0xFFF4F8F2),
          muted: Color(0xFF9DA4AF),
          primary: Color(0xFFD7FF3C),
          secondary: Color(0xFF8B66FF),
          tertiary: Color(0xFF39D5FF),
          success: Color(0xFF32D17C),
          warning: Color(0xFFFFC93C),
          error: Color(0xFFFF5B66),
        );
      case RunninSkin.matrix:
        // Inspirada em terminal MS-DOS / fósforo verde: fundo quase preto,
        // texto cinza-claro (CRT), acento verde (0/204/92) e cinza.
        return const RunninPalette(
          id: 'matrix',
          label: 'Matrix',
          background: Color(0xFF010601),
          surface: _kCardSurface,
          surfaceAlt: _kCardSurfaceAlt,
          border: Color(0xFF193823),
          text: Color(0xFFD2DAD2),
          muted: Color(0xFF6E7A6E),
          primary: Color(0xFF00CC5C), // verde solicitado (RGB 0/204/92)
          secondary: Color(0xFF9AA39A), // cinza
          tertiary: Color(0xFF00A84B), // verde mais escuro
          success: Color(0xFF00CC5C),
          warning: Color(0xFFCBB300),
          error: Color(0xFFE05050),
        );
    }
  }
}

@immutable
class RunninThemeTokens extends ThemeExtension<RunninThemeTokens> {
  final RunninPalette palette;
  final RunninTypography typography;

  RunninThemeTokens({required this.palette})
      : typography = RunninTypography.build(palette.text, palette.muted);

  const RunninThemeTokens._({required this.palette, required this.typography});

  @override
  RunninThemeTokens copyWith({RunninPalette? palette}) {
    final p = palette ?? this.palette;
    return RunninThemeTokens._(
      palette: p,
      typography: RunninTypography.build(p.text, p.muted),
    );
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

  RunninTypography get runninType {
    final tokens = Theme.of(this).extension<RunninThemeTokens>();
    return tokens?.typography ??
        RunninTypography.build(
          RunninSkin.artico.palette.text,
          RunninSkin.artico.palette.muted,
        );
  }
}
