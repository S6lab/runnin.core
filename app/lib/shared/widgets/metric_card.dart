import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Card de valor numérico — distância, pace, BPM, XP, streak, benchmark.
/// Usado em home, report, history e gamificação.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? accentColor;
  final Widget? trailing;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final color = accentColor ?? palette.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelCaps,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(value, style: type.dataMd.copyWith(color: color)),
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
                      style: type.bodySm,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
