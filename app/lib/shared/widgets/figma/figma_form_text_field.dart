import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaFormTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextStyle? placeholderStyle;
  final double height;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;

  const FigmaFormTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.placeholderStyle,
    this.height = 48.5,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<FigmaFormTextField> createState() => _FigmaFormTextFieldState();
}

class _FigmaFormTextFieldState extends State<FigmaFormTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: FigmaColors.surfaceInput,
        border: Border.all(
          color: _hasFocus ? FigmaColors.borderCyanActive : FigmaColors.borderInput,
          width: 1.041,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        readOnly: widget.readOnly || !widget.enabled,
        onTap: widget.onTap,
        style: context.runninType.bodyMd.copyWith(
          color: widget.enabled ? context.runninPalette.text : FigmaColors.textDim,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: widget.placeholderStyle ?? context.runninType.bodyMd.copyWith(color: FigmaColors.textPlaceholder),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }
}
