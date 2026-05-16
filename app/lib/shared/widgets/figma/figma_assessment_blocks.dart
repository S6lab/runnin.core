import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaCyanInfoBlock extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String body;
  final Widget? bodyWidget;

  const FigmaCyanInfoBlock({
    super.key,
    this.icon,
    required this.title,
    this.body = '',
    this.bodyWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17.74),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCardCyan,
        border: Border.all(
          color: FigmaColors.borderCyan,
          width: FigmaDimensions.borderUniversal,
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: FigmaColors.brandCyan),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (bodyWidget != null)
                  bodyWidget!
                else
                  Text(
                    body,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 19.2 / 12,
                      color: FigmaColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FigmaHealthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FigmaHealthChip({
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
        height: 41.4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? FigmaColors.textPrimary
                : FigmaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class FigmaNumericInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String unit;
  final String? placeholder;

  const FigmaNumericInputField({
    super.key,
    this.controller,
    required this.label,
    required this.unit,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FigmaNumericInputField._fieldLabel(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 77.5,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 28 / 28,
              letterSpacing: -0.84,
              color: FigmaColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.84,
                color: FigmaColors.textDim,
              ),
              filled: true,
              fillColor: FigmaColors.surfaceInput,
              contentPadding: const EdgeInsets.all(16),
              border: _border(),
              enabledBorder: _border(),
              focusedBorder: _border(FigmaColors.borderCyanActive),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unit,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: FigmaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  static Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.65,
        color: FigmaColors.textSecondary,
      ),
    );
  }

  static OutlineInputBorder _border([Color? color]) {
    return OutlineInputBorder(
      borderRadius: FigmaBorderRadius.zero,
      borderSide: BorderSide(
        color: color ?? FigmaColors.borderInput,
        width: FigmaDimensions.borderUniversal,
      ),
    );
  }
}

class FigmaTimePeriodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hours;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const FigmaTimePeriodCard({
    super.key,
    required this.icon,
    required this.label,
    required this.hours,
    required this.hint,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 109.8,
        height: 138.5,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: FigmaColors.brandCyan),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FigmaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hours,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textGhost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
