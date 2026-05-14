import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

/// Consistent loading indicator widget.
///
/// Shows a centered circular progress indicator with optional message.
/// Use for loading states while fetching data or processing requests.
class LoadingWidget extends StatelessWidget {
  /// Optional message to display below the spinner
  final String? message;

  /// Whether to show a full-screen loader or inline loader
  final bool fullScreen;

  /// Whether to wrap in AppPanel (only applies when fullScreen = false)
  final bool usePanel;

  /// Fixed height when using panel (defaults to 160)
  final double? height;

  const LoadingWidget({
    super.key,
    this.message,
    this.fullScreen = false,
    this.usePanel = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    final spinner = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: palette.primary,
          strokeWidth: 2,
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: palette.muted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(child: spinner);
    }

    if (usePanel) {
      return AppPanel(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: height ?? 160,
          child: Center(child: spinner),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: spinner,
      ),
    );
  }
}

/// 8-stage loading indicator for plan generation progress.
///
/// Shows 8 progressive stages with current status, completed indicators,
/// and visual progression bar. Used during plan generation and refresh.
class EightStageLoadingWidget extends StatelessWidget {
  final GenerationProgress progress;
  final String? title;
  final String? subtitle;

  const EightStageLoadingWidget({
    super.key,
    required this.progress,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: context.runninType.displaySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        _EightStageProgress(progress: progress),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _EightStageProgress extends StatelessWidget {
  final GenerationProgress progress;

  const _EightStageProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(8, (index) {
            final stageNum = index + 1;
            final isCompleted = stageNum < progress.currentStage;
            final isCurrent = stageNum == progress.currentStage;
            final isUpcoming = stageNum > progress.currentStage;

            return Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? palette.primary
                        : isCurrent
                            ? palette.primary.withValues(alpha: 0.2)
                            : palette.surfaceAlt,
                    border: Border.all(
                      color: isCompleted || isCurrent
                          ? palette.primary
                          : palette.border,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: palette.background,
                          )
                        : Text(
                            '$stageNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? palette.primary
                                  : isUpcoming
                                      ? palette.muted
                                      : palette.background,
                            ),
                          ),
                  ),
                ),
                if (index < 7)
                  Container(
                    width: 12,
                    height: 2,
                    color: isCompleted ? palette.primary : palette.border,
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          'Etapa ${progress.currentStage} de ${progress.totalStages}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.primary,
          ),
        ),
      ],
    );
  }
}
