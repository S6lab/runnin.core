import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaSelectionButton extends StatelessWidget {
  final String label;
  /// Linha secundária muted explicando a opção (ex: o que o coach fala
  /// em cada frequência). Null mantém o layout label-only original.
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const FigmaSelectionButton({
    super.key,
    required this.label,
    this.description,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56.5),
        padding: const EdgeInsets.symmetric(horizontal: 21.74, vertical: 14),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              softWrap: true,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 20 / 13.5,
                letterSpacing: 0,
                color: selected
                    ? FigmaColors.textPrimary
                    : const Color(0xB3FFFFFF),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                softWrap: true,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  height: 15 / 10.5,
                  letterSpacing: 0.2,
                  color: FigmaColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
