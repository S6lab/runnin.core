import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Card de valor numérico — distância, pace, BPM, XP, streak, benchmark.
/// Usado em home, report, history e gamificação.
///
/// Suporta 4 variantes Figma (HOME.md Seção 04):
/// 1. PACE TREND - value + delta + sub + chart
/// 2. CARDÍACO - value + delta + sub + zone bar + cardio label
/// 3. BENCHMARK - background ciano sólido + large value
/// 4. STREAK - value + unit + details list
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final Widget? trailing;

  /// Delta change indicator (ex: "↓18s", "↓3")
  final String? delta;
  final Color? deltaColor;

  /// Sub-label below value (ex: "/km · último treino")
  final String? sub;

  /// Optional chart widget at bottom (PACE TREND variant)
  final Widget? chart;

  /// Custom background color (BENCHMARK variant uses #00D4FF)
  final Color? backgroundColor;

  /// Zone bar for CARDÍACO variant
  final bool showZoneBar;

  /// Cardio label for CARDÍACO variant (ex: "CORRIDA 152")
  final String? cardioLabel;
  final Color? cardioLabelColor;

  /// Details list for STREAK variant
  final List<MapEntry<String, String>>? details;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.trailing,
    this.delta,
    this.deltaColor,
    this.sub,
    this.chart,
    this.backgroundColor,
    this.showZoneBar = false,
    this.cardioLabel,
    this.cardioLabelColor,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final bool isBenchmark = backgroundColor != null;
    final Color effectiveBgColor = backgroundColor ?? palette.surface;
    final Color effectiveBorderColor = isBenchmark
        ? Colors.transparent
        : palette.border;

    final Color labelColor = isBenchmark
        ? const Color(0xFF050510).withValues(alpha: 0.7)
        : palette.muted;

    final Color effectiveValueColor = valueColor ??
        (isBenchmark ? const Color(0xFF050510) : palette.text);

    final Color subColor = isBenchmark
        ? const Color(0xFF050510).withValues(alpha: 0.6)
        : palette.muted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        border: Border.all(color: effectiveBorderColor, width: 1.741),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelCaps.copyWith(color: labelColor),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Value + unit row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    value,
                    style: isBenchmark
                        ? type.dataMd.copyWith(
                            fontSize: 36,
                            color: effectiveValueColor,
                          )
                        : type.dataMd.copyWith(color: effectiveValueColor),
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
                      style: type.labelCaps.copyWith(color: labelColor),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Delta indicator
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: type.labelCaps.copyWith(
                color: deltaColor ?? const Color(0xFF00D4FF),
              ),
            ),
          ],

          // Sub-label
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: type.bodySm.copyWith(color: subColor),
            ),
          ],

          // Cardio label + zone bar (CARDÍACO variant)
          if (cardioLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              cardioLabel!,
              style: type.labelMd.copyWith(
                color: cardioLabelColor ?? const Color(0xFFFF6B35),
              ),
            ),
          ],
          if (showZoneBar) ...[
            const SizedBox(height: 8),
            _ZoneBar(),
          ],

          // Details list (STREAK variant)
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...details!.map((entry) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: palette.border,
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: type.labelCaps,
                    ),
                    Text(
                      entry.value,
                      style: type.labelMd.copyWith(color: palette.text),
                    ),
                  ],
                ),
              ),
            )),
          ],

          // Chart widget (PACE TREND variant)
          if (chart != null) ...[
            const SizedBox(height: 12),
            chart!,
          ],
        ],
      ),
    );
  }
}

/// Zone bar para variante CARDÍACO (5 segmentos de cores)
class _ZoneBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const zones = [
      Color(0xFF3B82F6), // Z1 blue
      Color(0xFF22C55E), // Z2 green
      Color(0xFFEAB308), // Z3 yellow
      Color(0xFFF97316), // Z4 orange
      Color(0xFFEF4444), // Z5 red
    ];

    return Row(
      children: zones.map((color) => Expanded(
        child: Container(
          height: 8,
          color: color,
        ),
      )).toList(),
    );
  }
}
