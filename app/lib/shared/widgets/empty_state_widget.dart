import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Consistent empty state widget for when there's no data to display.
///
/// Shows an icon, title, subtitle, and optional call-to-action button.
/// Use when a list is empty, a search returns no results, or user has no content yet.
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Primary message (title)
  final String title;

  /// Optional secondary message (subtitle)
  final String? subtitle;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onAction;

  /// Whether to show a full-screen empty state or inline
  final bool fullScreen;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.fullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    final content = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: fullScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: palette.muted.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: context.runninType.displaySm.copyWith(
            color: palette.text,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.7),
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: content,
    );
  }
}
