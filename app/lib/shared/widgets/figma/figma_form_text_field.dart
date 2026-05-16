import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaFormTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextStyle? placeholderStyle;
  final double height;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const FigmaFormTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.placeholderStyle,
    this.height = 48.5,
    this.maxLength,
    this.onChanged,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholderStyle = GoogleFonts.jetBrainsMono(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: FigmaColors.textPlaceholder,
    );

    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        obscureText: obscureText,
        autofocus: autofocus,
        readOnly: readOnly,
        textCapitalization: textCapitalization,
        onTap: onTap,
        inputFormatters: inputFormatters,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: FigmaColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: placeholderStyle ?? defaultPlaceholderStyle,
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
