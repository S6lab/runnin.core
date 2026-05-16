import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Minimal sparkline-style line chart for HIST trend cards per
/// `docs/figma/screens/HIST.md` §Volume/Pace/BPM charts. Custom-painted —
/// no external chart dependency.
///
/// Pass [values] (list of doubles); chart normalizes to its own bounds.
class FigmaChartLineSpark extends StatelessWidget {
  const FigmaChartLineSpark({
    super.key,
    required this.values,
    this.height = 80,
    this.lineColor = FigmaColors.brandCyan,
    this.fillGradient = true,
  });

  final List<double> values;
  final double height;
  final Color lineColor;
  final bool fillGradient;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparkPainter(
          values: values,
          lineColor: lineColor,
          fillGradient: fillGradient,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.lineColor,
    required this.fillGradient,
  });

  final List<double> values;
  final Color lineColor;
  final bool fillGradient;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    Offset point(int i) {
      final x = w * i / (values.length - 1);
      final y = h - ((values[i] - minV) / range) * (h - 4) - 2;
      return Offset(x, y);
    }

    final path = Path()..moveTo(0, point(0).dy);
    for (int i = 0; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }

    if (fillGradient) {
      final fillPath = Path.from(path)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.3),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = lineColor
        ..strokeWidth = 1.735,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.lineColor != lineColor;
}
