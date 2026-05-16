import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Exam upload CTA (dashed border — only dashed element in the app) per
/// `docs/figma/screens/PERFIL.md` §SAÚDE > EXAMES.
class FigmaExamUploadCTA extends StatelessWidget {
  const FigmaExamUploadCTA({
    super.key,
    required this.onTap,
    this.label = '+ Adicionar exame',
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          height: 54.5,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x0500D4FF), // rgba(0,212,255,0.02)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 18, color: FigmaColors.brandCyan),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 19.5 / 13,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x4F00D4FF) // rgba(0,212,255,0.31)
      ..strokeWidth = 1.735
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;

    void drawDashedLine(Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = (dx * dx + dy * dy).abs();
      if (len == 0) return;
      final dist = (b - a).distance;
      final steps = (dist / (dash + gap)).floor();
      final ux = dx / dist;
      final uy = dy / dist;
      for (int i = 0; i < steps; i++) {
        final s = a + Offset(ux * i * (dash + gap), uy * i * (dash + gap));
        final e = s + Offset(ux * dash, uy * dash);
        canvas.drawLine(s, e, paint);
      }
    }

    drawDashedLine(Offset.zero, Offset(size.width, 0));
    drawDashedLine(Offset(size.width, 0), Offset(size.width, size.height));
    drawDashedLine(Offset(size.width, size.height), Offset(0, size.height));
    drawDashedLine(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}

/// Owned exam card with file icon + name + analysis preview per
/// `docs/figma/screens/PERFIL.md` §SAÚDE > EXAMES.
class FigmaExamCard extends StatelessWidget {
  const FigmaExamCard({
    super.key,
    required this.examName,
    required this.fileName,
    required this.sizeLabel,
    required this.dateLabel,
    this.coachAnalysis,
    this.onTap,
  });

  final String examName;
  final String fileName;
  final String sizeLabel; // e.g. "2.4 MB"
  final String dateLabel; // e.g. "10/03/2026"
  final String? coachAnalysis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 22, color: FigmaColors.brandCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        examName,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          height: 19.5 / 13,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$fileName · $sizeLabel · $dateLabel',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (coachAnalysis != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0x05FF6B35),
                  border: Border(
                    left: BorderSide(color: FigmaColors.brandOrange, width: 1.735),
                  ),
                ),
                child: Text(
                  coachAnalysis!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 16.5 / 11,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
