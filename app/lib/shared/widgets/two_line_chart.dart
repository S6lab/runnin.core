import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/chart_tooltip.dart';

/// Um ponto do gráfico de 2 linhas. Valores em segundos (pace). Null = sem
/// dado naquele bucket (a linha quebra).
class TwoLineData {
  final String label;
  final double? lineA; // projetado
  final double? lineB; // médio/realizado
  const TwoLineData({required this.label, this.lineA, this.lineB});
}

/// Gráfico de 2 linhas (projetado vs médio) por bucket. Custom-paint, sem
/// dependência externa, no estilo do TwoToneBarChart. Pensado pra PACE:
/// menor = melhor, então o eixo é INVERTIDO (pace menor aparece mais no
/// topo = melhora pra cima). Legenda "PROJETADO"/"MÉDIO".
///
/// Interativo: toque num bucket pra ver um tooltip com o valor de cada
/// série (projetado/médio). Tocar de novo no mesmo bucket fecha.
class TwoLineChart extends StatefulWidget {
  final List<TwoLineData> data;
  final Color? lineAColor;
  final Color? lineBColor;
  /// Formata o valor (segundos) pros labels de eixo. Default: m:ss.
  final String Function(double)? formatValue;

  const TwoLineChart({
    super.key,
    required this.data,
    this.lineAColor,
    this.lineBColor,
    this.formatValue,
  });

  @override
  State<TwoLineChart> createState() => _TwoLineChartState();
}

class _TwoLineChartState extends State<TwoLineChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final aColor = widget.lineAColor ?? palette.primary;
    final bColor = widget.lineBColor ?? palette.secondary;
    final data = widget.data;

    final all = <double>[
      ...data.map((d) => d.lineA).whereType<double>(),
      ...data.map((d) => d.lineB).whereType<double>(),
    ];

    if (all.isEmpty) {
      return Center(
        child: Text(
          'Sem dados de pace no período.',
          style: type.bodySm.copyWith(color: palette.muted),
        ),
      );
    }

    final minV = all.reduce((a, b) => a < b ? a : b);
    final maxV = all.reduce((a, b) => a > b ? a : b);
    final fmt = widget.formatValue ?? _defaultFmt;

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eixo Y: melhor (pace menor) em cima.
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(minV), style: type.labelCaps.copyWith(fontSize: 8, color: palette.muted)),
                    Text(fmt(maxV), style: type.labelCaps.copyWith(fontSize: 8, color: palette.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final n = data.length;
                    double xFor(int i) => n <= 1 ? w / 2 : w * i / (n - 1);

                    Widget? tooltip;
                    if (_selected != null && _selected! < n) {
                      final i = _selected!;
                      final d = data[i];
                      const tw = 120.0;
                      final left = (xFor(i) - tw / 2).clamp(0.0, (w - tw).clamp(0.0, w));
                      tooltip = Positioned(
                        left: left,
                        top: 0,
                        child: ChartTooltip(
                          width: tw,
                          title: d.label,
                          rows: [
                            ChartTooltipRow(
                              color: aColor,
                              label: 'PROJETADO',
                              value: d.lineA == null ? '--' : fmt(d.lineA!),
                            ),
                            ChartTooltipRow(
                              color: bColor,
                              label: 'MÉDIO',
                              value: d.lineB == null ? '--' : fmt(d.lineB!),
                            ),
                          ],
                        ),
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final dx = details.localPosition.dx;
                        final i = n <= 1
                            ? 0
                            : (dx / (w / (n - 1))).round().clamp(0, n - 1);
                        setState(() => _selected = _selected == i ? null : i);
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _TwoLinePainter(
                                data: data,
                                minV: minV,
                                maxV: maxV,
                                aColor: aColor,
                                bColor: bColor,
                                gridColor: palette.border,
                                selectedIndex: _selected,
                              ),
                            ),
                          ),
                          ?tooltip,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 38),
            ...List.generate(
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
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: aColor, label: 'PROJETADO'),
            const SizedBox(width: 14),
            _LegendDot(color: bColor, label: 'MÉDIO'),
          ],
        ),
      ],
    );
  }

  static String _defaultFmt(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

class _TwoLinePainter extends CustomPainter {
  final List<TwoLineData> data;
  final double minV;
  final double maxV;
  final Color aColor;
  final Color bColor;
  final Color gridColor;
  final int? selectedIndex;

  _TwoLinePainter({
    required this.data,
    required this.minV,
    required this.maxV,
    required this.aColor,
    required this.bColor,
    required this.gridColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Domínio com padding de 15% pra a linha não colar nas bordas. Quando a
    // série é PLANA (todos os valores iguais — ex: só o pace projetado), o
    // range vira 1 e o padding centraliza a linha no meio do gráfico.
    final raw = maxV - minV;
    final isFlat = raw.abs() < 1e-6;
    final pad = (isFlat ? 1.0 : raw) * 0.15;
    final lo = minV - pad;
    final span = (isFlat ? 1.0 : raw) + pad * 2;

    // Linhas de grade horizontais (topo/meio/base).
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.8;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = h * f;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    double xFor(int i) =>
        data.length <= 1 ? w / 2 : w * i / (data.length - 1);
    // Eixo invertido: pace menor (melhor) fica mais no TOPO. Série plana
    // (todos iguais) é centralizada no meio.
    double yFor(double v) {
      final frac = isFlat ? 0.5 : ((v - lo) / span);
      return 4 + frac * (h - 8);
    }

    // Indicador vertical do bucket selecionado (atrás das linhas).
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < data.length) {
      final x = xFor(selectedIndex!);
      final marker = Paint()
        ..color = gridColor
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x, 0), Offset(x, h), marker);
    }

    void drawSeries(double? Function(TwoLineData) sel, Color color) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = color;
      Offset? prev;
      for (int i = 0; i < data.length; i++) {
        final v = sel(data[i]);
        if (v == null) {
          prev = null;
          continue;
        }
        final p = Offset(xFor(i), yFor(v));
        if (prev != null) canvas.drawLine(prev, p, stroke);
        // Ponto selecionado fica maior + anel pra destacar a leitura.
        if (i == selectedIndex) {
          canvas.drawCircle(p, 5.0, dot);
          canvas.drawCircle(
            p,
            5.0,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = color.withValues(alpha: 0.35)
              ..strokeWidth = 3.0,
          );
        } else {
          canvas.drawCircle(p, 2.6, dot);
        }
        prev = p;
      }
    }

    drawSeries((d) => d.lineA, aColor);
    drawSeries((d) => d.lineB, bColor);
  }

  @override
  bool shouldRepaint(_TwoLinePainter old) =>
      old.data != data ||
      old.minV != minV ||
      old.maxV != maxV ||
      old.selectedIndex != selectedIndex;
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
        Text(label, style: type.labelCaps.copyWith(fontSize: 9, letterSpacing: 0.8)),
      ],
    );
  }
}
