import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/feedback_toggle.dart';

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
    // FeedbackToggle (label + checkbox à direita) em vez de
    // FigmaSelectionButton: o selection button não tem indicador de on/off
    // — na página ALERTAS as linhas pareciam labels mortos, sem como saber
    // o que estava ativo.
    return FeedbackToggle(
      label: widget.label,
      feedbackKey: widget.id,
      value: _enabled,
      onChanged: (v) {
        setState(() => _enabled = v);
        widget.onToggle(v);
      },
    );
  }
}
