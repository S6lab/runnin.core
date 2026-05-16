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
            color: palette.text,
            width: 1.735,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            _BackButton(onPressed: onBack),
            const SizedBox(width: 10.97),
          ],
          _LogoLockup(palette),
          const SizedBox(width: 4),
          const _Separator(),
          const SizedBox(width: 4),
          Text(
            breadcrumb,
            style: _getBreadcrumbStyle(context, palette),
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
  final VoidCallback? onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.zero,
      child: const Icon(Icons.arrow_back_ios_new_outlined),
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
        const Text('RUNNIN'),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: palette.primary,
          child: const Text(
            '.AI',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '/',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}
