import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';

class SettingsToggle extends StatefulWidget {
  final String id;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const SettingsToggle({
    super.key,
    required this.id,
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  @override
  State<SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<SettingsToggle> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return FigmaSelectionButton(
      label: widget.label,
      selected: _enabled,
      onTap: () {
        setState(() => _enabled = !_enabled);
        widget.onToggle(_enabled);
      },
    );
  }
}
