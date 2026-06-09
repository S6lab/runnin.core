import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Linha compacta "META / FEITO" pra uma métrica (distância, pace, duração).
/// Cores espelham `TwoToneBarChart`: planejado em primary (cyan), feito em
/// secondary (laranja). Usado no card de histórico e na prep page quando a
/// sessão do plano do dia já foi executada.
///
/// Quando `actual` é null, mostra só "META Xkm". Quando ambos presentes,
/// mostra duas pílulas lado-a-lado.
class PlannedVsActualRow extends StatelessWidget {
  final String label;
  final String planned;
  final String? actual;
  const PlannedVsActualRow({
    super.key,
    required this.label,
    required this.planned,
    this.actual,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: type.labelCaps.copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
              color: palette.muted,
            ),
          ),
        ),
        Expanded(
          child: _Pill(
            value: planned,
            color: palette.primary,
            badge: 'META',
          ),
        ),
        if (actual != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              value: actual!,
              color: palette.secondary,
              badge: 'FEITO',
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String value;
  final Color color;
  final String badge;
  const _Pill({required this.value, required this.color, required this.badge});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        color: color.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            badge,
            style: type.labelCaps.copyWith(
              fontSize: 8,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: type.labelMd.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
