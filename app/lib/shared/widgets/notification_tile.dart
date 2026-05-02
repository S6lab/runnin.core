import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Item da inbox de notificações do Coach na Home.
/// Suporta expansão inline, CTA primário e botão de dispensar.
class NotificationTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String preview;
  final String? fullText;
  final String? timestamp;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final VoidCallback? onDismiss;
  final bool initiallyExpanded;

  const NotificationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.preview,
    this.fullText,
    this.timestamp,
    this.ctaLabel,
    this.onCta,
    this.onDismiss,
    this.initiallyExpanded = false,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: InkWell(
        onTap: widget.fullText != null
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 16, color: palette.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: type.labelMd.copyWith(color: palette.text),
                    ),
                  ),
                  if (widget.timestamp != null)
                    Text(widget.timestamp!, style: type.labelCaps),
                  const SizedBox(width: 8),
                  if (widget.fullText != null)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: palette.muted,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _expanded && widget.fullText != null
                    ? widget.fullText!
                    : widget.preview,
                style: type.bodySm.copyWith(height: 1.5),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              if (_expanded && (widget.ctaLabel != null || widget.onDismiss != null)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.ctaLabel != null)
                      OutlinedButton(
                        onPressed: widget.onCta,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primary,
                          side: BorderSide(color: palette.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.ctaLabel!,
                          style: type.labelCaps.copyWith(color: palette.primary),
                        ),
                      ),
                    if (widget.ctaLabel != null && widget.onDismiss != null)
                      const SizedBox(width: 12),
                    if (widget.onDismiss != null)
                      OutlinedButton(
                        onPressed: widget.onDismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.muted,
                          side: BorderSide(color: palette.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'DISPENSAR',
                          style: type.labelCaps,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
