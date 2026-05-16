import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaGoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const FigmaGoogleSignInButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48.5),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0x0CFFFFFF),
          border: Border.all(
            width: 1.735,
            color: FigmaColors.borderInput,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(painter: _GoogleIconPainter()),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'ENTRAR COM GOOGLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    canvas.scale(sx, sy);

    canvas.drawPath(
      Path()
        ..moveTo(22.56, 12.25)
        ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0)
        ..lineTo(12.0, 10.0)
        ..lineTo(12.0, 14.26)
        ..lineTo(17.92, 14.26)
        ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
        ..lineTo(15.71, 20.34)
        ..lineTo(19.28, 20.34)
        ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
        ..close(),
      Paint()..color = const Color(0xFF4285F4),
    );

    canvas.drawPath(
      Path()
        ..moveTo(12.0, 23.0)
        ..cubicTo(14.97, 23.0, 17.46, 22.02, 19.28, 20.34)
        ..lineTo(15.71, 17.57)
        ..cubicTo(14.73, 18.23, 13.48, 18.63, 12.0, 18.63)
        ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.86, 14.1)
        ..lineTo(2.18, 14.1)
        ..lineTo(2.18, 16.94)
        ..cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0)
        ..close(),
      Paint()..color = const Color(0xFF34A853),
    );

    canvas.drawPath(
      Path()
        ..moveTo(5.84, 14.09)
        ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12.0)
        ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
        ..lineTo(5.84, 7.07)
        ..lineTo(2.18, 7.07)
        ..cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0)
        ..cubicTo(1.0, 13.78, 1.43, 15.45, 2.18, 16.93)
        ..lineTo(5.03, 14.71)
        ..lineTo(5.84, 14.09)
        ..close(),
      Paint()..color = const Color(0xFFFBBC05),
    );

    canvas.drawPath(
      Path()
        ..moveTo(12.0, 5.38)
        ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
        ..lineTo(19.36, 3.87)
        ..cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0)
        ..cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.07)
        ..lineTo(5.84, 9.91)
        ..cubicTo(6.69, 7.31, 9.12, 5.38, 11.98, 5.38)
        ..close(),
      Paint()..color = const Color(0xFFEA4335),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
