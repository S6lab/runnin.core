import 'package:flutter/material.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 0),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.03,
      ),
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? titleWidget
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [titleWidget, trailing!],
            ),
    );
  }
}
