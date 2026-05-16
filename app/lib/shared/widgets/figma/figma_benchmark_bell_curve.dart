import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Normal-distribution bell curve with user position marker per
/// `docs/figma/screens/HIST.md` tela 5 §Benchmark. Custom-painted SVG-style
/// curve; user position marker drawn at [userPercentile] (0–100).
class FigmaBenchmarkBellCurve extends StatelessWidget {
  const FigmaBenchmarkBellCurve({
    super.key,
    required this.userPercentile,
    this.height = 120,
  });

  final double userPercentile;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BellCurvePainter(userPercentile: userPercentile),
      ),
    );
  }
}

class _BellCurvePainter extends CustomPainter {
  _BellCurvePainter({required this.userPercentile});
  final double userPercentile;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bell curve path
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FigmaColors.brandCyan.withValues(alpha: 0.35),
          FigmaColors.brandCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = FigmaColors.brandCyan
      ..strokeWidth = 1.735;

    final path = Path();
    path.moveTo(0, h);
    for (double x = 0; x <= w; x += 1) {
      final norm = (x / w - 0.5) * 6;
      final y = math.exp(-norm * norm / 2);
      path.lineTo(x, h - y * (h - 8));
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // User marker
    final ux = (userPercentile.clamp(0, 100) / 100) * w;
    final norm = (ux / w - 0.5) * 6;
    final uy = h - math.exp(-norm * norm / 2) * (h - 8);
    final markerPaint = Paint()..color = FigmaColors.brandOrange;
    canvas.drawCircle(Offset(ux, uy), 5, markerPaint);
    canvas.drawLine(
      Offset(ux, uy),
      Offset(ux, h),
      Paint()
        ..color = FigmaColors.brandOrange
        ..strokeWidth = 1.0,
    );

    // X-axis labels (P10, P50, P90)
    final labelStyle = TextStyle(
      color: FigmaColors.textMuted,
      fontSize: 9,
      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
    );
    for (final (pct, label) in <(double, String)>[(10, 'P10'), (50, 'P50'), (90, 'P90')]) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pct / 100 * w - tp.width / 2, h - tp.height));
    }
  }

  @override
  bool shouldRepaint(_BellCurvePainter old) =>
      old.userPercentile != userPercentile;
}
