import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaOtpTextField extends StatelessWidget {
  final TextEditingController? controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const FigmaOtpTextField({
    super.key,
    this.controller,
    this.length = 6,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderText = List.filled(length, '_').join(' ');

    return SizedBox(
      height: 48.5,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        maxLength: length,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 4.2,
          color: FigmaColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: placeholderText,
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 4.2,
            color: FigmaColors.textPlaceholder,
          ),
          counterText: '',
          filled: true,
          fillColor: FigmaColors.surfaceInput,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: _border(),
          enabledBorder: _border(),
          focusedBorder: _border(FigmaColors.borderCyanActive),
        ),
      ),
    );
  }

  OutlineInputBorder _border([Color? color]) {
    return OutlineInputBorder(
      borderRadius: FigmaBorderRadius.zero,
      borderSide: BorderSide(
        color: color ?? FigmaColors.borderInput,
        width: FigmaDimensions.borderUniversal,
      ),
    );
  }
}
