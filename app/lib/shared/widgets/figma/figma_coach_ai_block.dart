import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

enum CoachAIBlockVariant {
  assessment,
  appGeneral,
  insideCard,
}

class FigmaCoachAIBlock extends StatelessWidget {
  final Widget child;
  final CoachAIBlockVariant variant;

  const FigmaCoachAIBlock({
    super.key,
    required this.child,
    this.variant = CoachAIBlockVariant.appGeneral,
  });

  @override
  Widget build(BuildContext context) {
    final double borderWidth;
    final Color bgColor;

    switch (variant) {
      case CoachAIBlockVariant.assessment:
        bgColor = const Color(0x0FFF6B35);
        borderWidth = 2.0;
      case CoachAIBlockVariant.appGeneral:
        bgColor = FigmaColors.surfaceCardOrange;
        borderWidth = FigmaDimensions.borderUniversal;
      case CoachAIBlockVariant.insideCard:
        bgColor = const Color(0x05FF6B35);
        borderWidth = FigmaDimensions.borderUniversal;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(
            color: FigmaColors.borderOrange,
            width: borderWidth,
          ),
        ),
      ),
      child: child,
    );
  }
}

class FigmaCoachAIBreadcrumb extends StatelessWidget {
  final String action;

  const FigmaCoachAIBreadcrumb({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: FigmaColors.brandOrange,
        ),
        const SizedBox(width: 4),
        Text(
          'COACH.AI',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.8,
            color: FigmaColors.brandOrange,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '> $action',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.8,
            color: FigmaColors.textDim,
          ),
        ),
      ],
    );
  }
}
