import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class StepNavigationButtons extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  const StepNavigationButtons({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        if (canGoPrevious)
          Expanded(
            child: TextButton.icon(
              onPressed: onPreviousPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: Icon(Icons.chevron_left_outlined, color: palette.muted),
              label: Text(
                'VOLTAR',
                style: context.runninType.labelCaps.copyWith(color: palette.primary),
              ),
            ),
          )
        else
          const Expanded(child: SizedBox.shrink()),
        if (canGoPrevious) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onNextPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: canGoNext
                ? Icon(Icons.chevron_right_outlined, color: palette.background)
                : const SizedBox.shrink(),
            label: Text(
              canGoNext ? 'AVANÇAR' : 'FINALIZAR',
              style: context.runninType.labelCaps.copyWith(color: palette.background),
            ),
          ),
        ),
      ],
    );
  }
}
