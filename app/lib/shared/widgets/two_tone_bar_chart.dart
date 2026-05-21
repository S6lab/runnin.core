import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/chart_tooltip.dart';

/// Gráfico de barras duplas (planejado vs feito) por bucket.
///
/// Renderiza, pra cada bucket, duas barras lado-a-lado:
/// - barra 1 (palette.primary): volume planejado
/// - barra 2 (palette.secondary): volume executado
///
/// Sem dependência externa, mesma abordagem do SimpleBarChart pra
/// manter o look consistente. Quando planned ou executed for 0 num
/// bucket, mostra só a outra (ou um stub no chão se ambos 0).
///
/// Interativo: toque num bucket pra ver um tooltip com o valor de cada
/// série (planejado/feito) daquele bucket. Tocar de novo fecha.
class TwoToneBarData {
  final double planned;
  final double executed;
  final String label;
  const TwoToneBarData({
    required this.planned,
    required this.executed,
    required this.label,
  });
}

class TwoToneBarChart extends StatefulWidget {
  final List<TwoToneBarData> data;
  final Color? plannedColor;
  final Color? executedColor;
  /// Formata o valor pros tooltips. Default: "X.Ykm".
  final String Function(double)? formatValue;
  const TwoToneBarChart({
    super.key,
    required this.data,
    this.plannedColor,
    this.executedColor,
    this.formatValue,
  });

  @override
  State<TwoToneBarChart> createState() => _TwoToneBarChartState();
}

class _TwoToneBarChartState extends State<TwoToneBarChart> {
  int? _selected;

  String _fmt(double v) =>
      widget.formatValue?.call(v) ?? '${v.toStringAsFixed(1)}km';

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final pColor = widget.plannedColor ?? palette.primary;
    final eColor = widget.executedColor ?? palette.secondary;
    final data = widget.data;

    final maxVal = data.fold(0.0, (m, d) {
      final v = d.planned > d.executed ? d.planned : d.executed;
      return v > m ? v : m;
    });

    return Column(
      children: [
        Expanded(
          // LayoutBuilder dá uma altura FINITA pra calcular o pixel de cada
          // barra. Antes usávamos FractionallySizedBox dentro de Column, que
          // recebe altura infinita e estoura o layout quando há dado > 0.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              Widget bar(double value, Color color, bool dim) {
                final frac = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;
                final px = value > 0 ? (frac * h).clamp(2.0, h) : 2.0;
                return Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: px,
                      color: value > 0
                          ? color.withValues(alpha: dim ? 0.3 : 0.85)
                          : palette.border,
                    ),
                  ),
                );
              }

              final bars = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(data.length, (i) {
                  final d = data[i];
                  final dim = _selected != null && _selected != i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                          () => _selected = _selected == i ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bar(d.planned, pColor, dim),
                            const SizedBox(width: 2),
                            bar(d.executed, eColor, dim),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );

              Widget? tooltip;
              if (_selected != null && _selected! < data.length) {
                final i = _selected!;
                final d = data[i];
                const tw = 116.0;
                final center = (i + 0.5) * w / data.length;
                final left = (center - tw / 2).clamp(0.0, w - tw);
                tooltip = Positioned(
                  left: left,
                  top: 0,
                  child: ChartTooltip(
                    width: tw,
                    title: d.label,
                    rows: [
                      ChartTooltipRow(color: pColor, label: 'PLANEJADO', value: _fmt(d.planned)),
                      ChartTooltipRow(color: eColor, label: 'FEITO', value: _fmt(d.executed)),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: bars),
                  ?tooltip,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(
            data.length,
            (i) => Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _selected = _selected == i ? null : i),
                child: Text(
                  data[i].label,
                  textAlign: TextAlign.center,
                  style: type.labelCaps.copyWith(
                    fontSize: 8,
                    color: _selected == i ? palette.text : null,
                    fontWeight: _selected == i ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: pColor, label: 'PLANEJADO'),
            const SizedBox(width: 14),
            _LegendDot(color: eColor, label: 'FEITO'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: type.labelCaps.copyWith(fontSize: 9, letterSpacing: 0.8),
        ),
      ],
    );
  }
}
