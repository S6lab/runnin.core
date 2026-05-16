import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class OnboardingStepCode extends StatelessWidget {
  final String value;

  const OnboardingStepCode(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '// $value',
      style: context.runninType.labelMd.copyWith(
        color: context.runninPalette.primary,
      ),
    );
  }
}

class OnboardingInlineNotice extends StatelessWidget {
  final String text;
  final Color color;

  const OnboardingInlineNotice({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(12),
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.35),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
