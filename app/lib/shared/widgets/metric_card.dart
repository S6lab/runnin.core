import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Numeric metric tile. Used in HOME §04 Performance grid, history,
/// gamification, training reports.
///
/// Pixel-perfect Figma values per `docs/figma/screens/HOME.md` lines 134–168.
/// Supports the four §04 variants:
///   1. PACE TREND  — value + delta + sub + chart
///   2. CARDÍACO    — value + delta + sub + cardio label + zone bar
///   3. BENCHMARK   — solid cyan bg + 36 px value + sub
///   4. STREAK      — value + unit + details list
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    @Deprecated('Use valueColor (matches Figma DESIGN_SYSTEM spec).')
    this.accentColor,
    this.trailing,
    this.delta,
    this.deltaColor,
    this.sub,
    this.chart,
    this.backgroundColor,
    this.showZoneBar = false,
    this.zoneBarProportions,
    this.cardioLabel,
    this.cardioLabelColor,
    this.details,
  });

  /// ALL CAPS metric label (e.g. "PACE TREND"). Caller controls casing.
  final String label;

  /// Big number / text shown as the headline (e.g. "5:26", "TOP 30%", "12").
  final String value;

  /// Optional unit suffix shown next to [value] (e.g. "dias", "km").
  final String? unit;

  /// Color applied to [value]. Spec name. Defaults to white (or `#050510`
  /// when [backgroundColor] is set, for the BENCHMARK variant).
  final Color? valueColor;

  /// Deprecated alias for [valueColor] kept for backward compatibility
  /// with existing call sites (gamification, history, training pages).
  final Color? accentColor;

  /// Optional widget at the top-right of the label row.
  final Widget? trailing;

  /// Delta change indicator (e.g. "↓18s", "↓3"). Rendered below [value].
  final String? delta;

  /// Color for [delta]. Defaults to brand cyan.
  final Color? deltaColor;

  /// Sub-label shown below [delta] (e.g. "/km · último treino").
  final String? sub;

  /// Optional chart slot at the bottom of the card (e.g. cyan area chart
  /// for PACE TREND).
  final Widget? chart;

  /// Custom background color. Setting this enables the BENCHMARK variant
  /// (solid cyan bg + dark text + transparent border).
  final Color? backgroundColor;

  /// Whether to render the 5-segment Z1–Z5 zone bar (CARDÍACO variant).
  final bool showZoneBar;

  /// Proportions for the zone bar segments. Defaults to even fifths.
  final List<double>? zoneBarProportions;

  /// Cardio label text rendered above the zone bar (e.g. "CORRIDA 152").
  final String? cardioLabel;

  /// Color for [cardioLabel]. Defaults to brand orange.
  final Color? cardioLabelColor;

  /// Detail rows for the STREAK variant (label → value pairs).
  final List<MapEntry<String, String>>? details;

  @override
  Widget build(BuildContext context) {
    final isBenchmark = backgroundColor != null;
    final effectiveBg = backgroundColor ?? FigmaColors.surfaceCard;
    final effectiveBorder = isBenchmark ? Colors.transparent : FigmaColors.borderDefault;
    final labelColor = isBenchmark
        ? FigmaColors.bgBase.withValues(alpha: 0.70)
        : FigmaColors.textMuted;
    final effectiveValueColor = valueColor ??
        accentColor ??
        (isBenchmark ? FigmaColors.bgBase : FigmaColors.textPrimary);
    final subColor = isBenchmark
        ? FigmaColors.bgBase.withValues(alpha: 0.60)
        : FigmaColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveBg,
        border: Border.all(color: effectiveBorder, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabelRow(label: label, labelColor: labelColor, trailing: trailing),
          const SizedBox(height: 8),
          _ValueRow(
            value: value,
            unit: unit,
            valueColor: effectiveValueColor,
            unitColor: labelColor,
            isBenchmark: isBenchmark,
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 16.5 / 11,
                fontWeight: FontWeight.w400,
                color: deltaColor ?? FigmaColors.brandCyan,
              ),
            ),
          ],
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 15 / 10,
                fontWeight: FontWeight.w400,
                color: subColor,
              ),
            ),
          ],
          if (cardioLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              cardioLabel!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 19.5 / 13,
                fontWeight: FontWeight.w500,
                color: cardioLabelColor ?? FigmaColors.brandOrange,
              ),
            ),
          ],
          if (showZoneBar) ...[
            const SizedBox(height: 8),
            _ZoneBar(proportions: zoneBarProportions),
          ],
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final entry in details!) _DetailRow(label: entry.key, value: entry.value),
          ],
          if (chart != null) ...[
            const SizedBox(height: 12),
            chart!,
          ],
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.labelColor, this.trailing});

  final String label;
  final Color labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w400,
              color: labelColor,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing!),
          ),
        ],
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.value,
    required this.valueColor,
    required this.unitColor,
    required this.isBenchmark,
    this.unit,
  });

  final String value;
  final String? unit;
  final Color valueColor;
  final Color unitColor;
  final bool isBenchmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isBenchmark ? 36 : 28,
                height: 1,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  height: 16.5 / 11,
                  fontWeight: FontWeight.w400,
                  color: unitColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: FigmaColors.borderDefault, width: 1),
          ),
        ),
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 15 / 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textMuted,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 19.5 / 13,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5-segment zone bar (Z1–Z5) per DESIGN_SYSTEM.md §2.8.
class _ZoneBar extends StatelessWidget {
  const _ZoneBar({this.proportions});

  final List<double>? proportions;

  static const _zones = [
    Color(0xFF3B82F6), // Z1 blue
    Color(0xFF22C55E), // Z2 green
    Color(0xFFEAB308), // Z3 yellow
    Color(0xFFF97316), // Z4 orange
    Color(0xFFEF4444), // Z5 red
  ];

  @override
  Widget build(BuildContext context) {
    final p = proportions ?? const [0.2, 0.2, 0.2, 0.2, 0.2];
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          for (int i = 0; i < _zones.length; i++)
            Expanded(
              flex: (p[i] * 100).round(),
              child: ColoredBox(color: _zones[i]),
            ),
        ],
      ),
    );
  }
}
