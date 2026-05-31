import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FeedbackToggle extends StatelessWidget {
  final String label;
  final String feedbackKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  const FeedbackToggle({
    super.key,
    required this.label,
    required this.feedbackKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 21.74, vertical: 14),
        decoration: BoxDecoration(
          color: value ? FigmaColors.selectionActiveBg : FigmaColors.surfaceCard,
          border: Border.all(
            color: value ? FigmaColors.selectionActiveBorder : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.runninType.bodyMd.copyWith(
                  fontWeight: FontWeight.w500,
                  color: value ? FigmaColors.textPrimary : const Color(0xB3FFFFFF),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? context.runninPalette.primary : Colors.transparent,
                border: Border.all(
                  color: value ? context.runninPalette.primary : FigmaColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
