import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/steps/domain/entities/step.dart';

class StepCard extends StatelessWidget {
  final AppStep step;
  final bool isActive;
  final VoidCallback? onTap;
  final List<StepValidationResult>? validationErrors;

  const StepCard({
    super.key,
    required this.step,
    required this.isActive,
    this.onTap,
    this.validationErrors,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? palette.surface
              : palette.background,
          border: Border.all(
            color: isActive
                ? palette.primary
                : (step.status == StepStatus.error || validationErrors?.isNotEmpty == true)
                    ? palette.error
                    : palette.border,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  step.title.toUpperCase(),
                  style: type.labelCaps.copyWith(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (step.status == StepStatus.completed)
                  Icon(
                    Icons.check_circle,
                    color: palette.success,
                    size: 20,
                  )
                else if (step.status == StepStatus.error)
                  Icon(
                    Icons.error_outline,
                    color: palette.error,
                    size: 20,
                  ),
              ],
            ),
            if (step.description != null) ...[
              const SizedBox(height: 8),
              Text(
                step.description!,
                style: type.bodySm.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
            if (validationErrors != null && validationErrors!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: validationErrors!.map((error) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: palette.error, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              error.message,
                             style: type.bodySm.copyWith(
                               color: palette.error,
                             ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
