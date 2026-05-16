import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaFormTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextStyle? placeholderStyle;
  final double height;
  final int? maxLength;

  const FigmaFormTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.placeholderStyle,
    this.height = 48.5,
    this.maxLength,
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
          width: 1.735,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        style: context.runninType.bodyMd.copyWith(
          color: context.runninPalette.text,
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
