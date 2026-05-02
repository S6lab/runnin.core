import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Linha de configuração com label, subtítulo opcional e Switch.
/// Usado em alertas de corrida, notificações e ajustes.
class ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: type.labelMd),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: type.bodySm),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primary.withValues(alpha: 0.3),
            inactiveThumbColor: palette.muted,
            inactiveTrackColor: palette.border,
          ),
        ],
      ),
    );
  }
}
