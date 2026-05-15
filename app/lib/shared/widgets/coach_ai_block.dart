import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Coach.AI Brief card with colored left border.
/// Used in home, report, training and history sections.
class CoachAIBlock extends StatelessWidget {
  final String text;
  final bool isLoading;
  final Color? borderColor;
  final VoidCallback? onButtonPressed;

  const CoachAIBlock({
    super.key,
    required this.text,
    this.isLoading = false,
    this.borderColor,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = RunninSkin.cyber.palette;
    final type = RunninTypography.build(palette.text, palette.muted);
    final border = borderColor ?? palette.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.02),
        border: Border(left: BorderSide(color: border, width: 1.741)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COACH.AI',
            style: type.labelCaps.copyWith(color: border, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
                ),
                const SizedBox(width: 10),
                Text('Analisando...', style: type.bodySm),
              ],
            )
          else
            Text(
              text,
              style: type.bodyMd.copyWith(height: 1.6, color: palette.muted),
            ),
          const SizedBox(height: 16),
          if (!isLoading)
            Center(
              child: ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: const Color(0xFF050510),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('INICIAR SESSÃO ↗', style: type.labelMd.copyWith(leadingDistribution: TextLeadingDistribution.even)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_upward_outlined, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
