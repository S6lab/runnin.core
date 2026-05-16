import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaSelectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FigmaSelectionButton({
    super.key,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56.5,
        padding: const EdgeInsets.symmetric(horizontal: 21.74, vertical: 17.74),
        decoration: BoxDecoration(
          color: selected
              ? FigmaColors.selectionActiveBg
              : FigmaColors.surfaceCard,
          border: Border.all(
            color: selected
                ? FigmaColors.selectionActiveBorder
                : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 21 / 14,
            letterSpacing: 0,
            color: selected
                ? FigmaColors.textPrimary
                : const Color(0xB3FFFFFF),
          ),
        ),
      ),
    );
  }
}
