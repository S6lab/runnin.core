import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Section header pattern used across HOME §02–§07 (and similar dot-prefixed
/// section labels elsewhere in the app).
///
/// Layout: `[■]  LABEL  [BADGE]      ACTION`
///   - Colored dot (5.986 px square) at the leading edge
///   - All-caps label in the dot color, tracking 1.65 px
///   - Optional counter badge ("5"): Bold 9 px on the dot color background
///   - Optional trailing text action ("LIMPAR"): Medium 10 px, secondary
///
/// Per `docs/figma/screens/HOME.md` §02 header (lines 67–73) and the
/// generalized pattern of every Coach.AI/section header in the app.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.label,
    this.dotColor = FigmaColors.brandCyan,
    this.badge,
    this.action,
    this.onAction,
  });

  /// Section label, ALL CAPS by convention. Caller should already pass it
  /// uppercased (the widget does not transform).
  final String label;

  /// Color of the leading dot AND the label text. Defaults to brand cyan.
  /// Pass `FigmaColors.brandOrange` for Coach.AI sections.
  final Color dotColor;

  /// Optional numeric badge to render right after the label
  /// (e.g. "5" notifications). Bold 9 px on `dotColor` background.
  final String? badge;

  /// Optional trailing text action (e.g. "LIMPAR"). Tap handler in [onAction].
  final String? action;

  /// Tap handler for the trailing action. Required when [action] is set.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 5.986,
          height: 5.986,
          child: Opacity(
            opacity: 0.98,
            child: ColoredBox(color: dotColor),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              letterSpacing: 1.65,
              fontWeight: FontWeight.w400,
              color: dotColor,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          _BadgeCounter(text: badge!, color: dotColor),
        ],
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Text(
              action!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 15 / 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeCounter extends StatelessWidget {
  const _BadgeCounter({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17.386,
      height: 17.468,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          height: 13.5 / 9,
          fontWeight: FontWeight.w700,
          color: FigmaColors.bgBase,
        ),
      ),
    );
  }
}
