import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Bloco textual do Coach com borda lateral colorida.
/// Usado em home, report, training e history.
class CoachNarrativeCard extends StatelessWidget {
  final String text;
  final bool isLoading;
  final Color? borderColor;

  const CoachNarrativeCard({
    super.key,
    required this.text,
    this.isLoading = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final border = borderColor ?? palette.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: border, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COACH.AI',
            style: type.labelCaps.copyWith(color: border),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            Row(children: [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
              ),
              const SizedBox(width: 10),
              Text('Analisando...', style: type.bodySm),
            ])
          else
            Text(text, style: type.bodyMd.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
