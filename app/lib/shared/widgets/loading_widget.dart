import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
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
