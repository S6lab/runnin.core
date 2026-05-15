import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

import '../../domain/entities/step.dart';

class ValidationErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onFix;

  const ValidationErrorCard({
    super.key,
    required this.message,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.1),
        border: Border.all(color: palette.error),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.runninType.bodySm.copyWith(color: palette.error),
            ),
          ),
          if (onFix != null)
            TextButton(
              onPressed: onFix,
              style: TextButton.styleFrom(backgroundColor: palette.error),
              child: Text(
                'CORRIGIR',
                style: context.runninType.labelCaps.copyWith(color: palette.background),
              ),
            ),
        ],
      ),
    );
  }
}

class ValidationSuccessCard extends StatelessWidget {
  final String message;

  const ValidationSuccessCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.1),
        border: Border.all(color: palette.success),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: palette.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.runninType.bodySm.copyWith(color: palette.success),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildValidationFeedback({
  required BuildContext context,
  required List<StepValidationResult> errors,
  String? successMessage,
}) {
  if (errors.isNotEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: errors.map((error) => ValidationErrorCard(message: error.message)).toList(),
    );
  }

  if (successMessage != null && successMessage.isNotEmpty) {
    return ValidationSuccessCard(message: successMessage);
  }

  return const SizedBox.shrink();
}
