import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

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
class TwoLineChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final aColor = lineAColor ?? palette.primary;
    final bColor = lineBColor ?? palette.secondary;

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
    final fmt = formatValue ?? _defaultFmt;

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
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TwoLinePainter(
                    data: data,
                    minV: minV,
                    maxV: maxV,
                    aColor: aColor,
                    bColor: bColor,
                    gridColor: palette.border,
                  ),
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
                child: Text(
                  data[i].label,
                  textAlign: TextAlign.center,
                  style: type.labelCaps.copyWith(fontSize: 8),
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

  _TwoLinePainter({
    required this.data,
    required this.minV,
    required this.maxV,
    required this.aColor,
    required this.bColor,
    required this.gridColor,
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
        canvas.drawCircle(p, 2.6, dot);
        prev = p;
      }
    }

    drawSeries((d) => d.lineA, aColor);
    drawSeries((d) => d.lineB, bColor);
  }

  @override
  bool shouldRepaint(_TwoLinePainter old) =>
      old.data != data || old.minV != minV || old.maxV != maxV;
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
