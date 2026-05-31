import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ToggleAppearance appearance;

  const Toggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.appearance = const ToggleAppearance(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: appearance.activeColor ?? palette.primary,
      activeTrackColor: appearance.activeTrackColor ??
          (appearance.activeColor ?? palette.primary).withValues(alpha: 0.3),
      inactiveThumbColor:
          appearance.inactiveThumbColor ?? palette.muted,
      inactiveTrackColor: appearance.inactiveTrackColor ?? palette.border,
    );
  }
}

class ToggleAppearance {
  final Color? activeColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;

  const ToggleAppearance({
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
  });
}
