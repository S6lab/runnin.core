import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

/// Consistent error state widget with retry functionality.
///
/// Shows an error message with an optional retry button.
/// Use for network errors, API failures, and other recoverable errors.
class ErrorStateWidget extends StatelessWidget {
  /// The error message to display to the user
  final String message;

  /// Optional callback when the retry button is pressed
  final VoidCallback? onRetry;

  /// Whether to show a full-screen error or inline error
  final bool fullScreen;

  /// Optional icon to display with the error
  final IconData? icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.fullScreen = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    final content = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: fullScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 48,
            color: palette.muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          message,
          style: TextStyle(
            color: palette.muted,
            fontSize: 15,
            height: 1.4,
          ),
          textAlign: fullScreen ? TextAlign.center : TextAlign.left,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('TENTAR NOVAMENTE'),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: content,
        ),
      );
    }

    return AppPanel(child: content);
  }
}
