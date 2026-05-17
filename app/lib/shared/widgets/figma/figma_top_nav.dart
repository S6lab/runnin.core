import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class FigmaTopNav extends StatelessWidget {
  final String breadcrumb;
  final bool showBackButton;
  final VoidCallback? onBack;

  const FigmaTopNav({
    super.key,
    required this.breadcrumb,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    const double heightWithoutBack = 54.71;
    const double heightWithBack = 73.712;

    return Container(
      height: showBackButton ? heightWithBack : heightWithoutBack,
      padding: EdgeInsets.fromLTRB(24, 16, 20, showBackButton ? 17.355 : 17.735),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(
          bottom: BorderSide(
            color: palette.border,
            width: 1.041,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            _BackButton(
              color: palette.text,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 10.97),
          ],
          _LogoLockup(palette),
          const SizedBox(width: 4),
          _Separator(color: palette.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              breadcrumb,
              style: _getBreadcrumbStyle(context, palette),
              overflow: TextOverflow.fade,
              softWrap: false,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _getBreadcrumbStyle(BuildContext context, RunninPalette palette) {
    return context.runninType.labelCaps
        .copyWith(
          color: palette.muted,
          fontSize: 13,
          letterSpacing: 1.3,
        )
        .apply(letterSpacingDelta: 0);
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color color;

  const _BackButton({required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.zero,
      child: Icon(Icons.arrow_back_ios_new_outlined, color: color, size: 22),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  final RunninPalette palette;

  const _LogoLockup(this.palette);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RUNNIN',
          style: TextStyle(
            color: palette.text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: palette.primary,
          child: Text(
            '.AI',
            style: TextStyle(
              color: palette.background,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  final Color color;

  const _Separator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '/',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: color,
      ),
    );
  }
}
