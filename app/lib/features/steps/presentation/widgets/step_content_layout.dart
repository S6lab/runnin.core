import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class StepContentLayout extends StatelessWidget {
  final Widget stepTitle;
  final Widget? stepDescription;
  final Widget mainContent;
  final List<Widget>? optionalContents;

  const StepContentLayout({
    super.key,
    required this.stepTitle,
    this.stepDescription,
    required this.mainContent,
    this.optionalContents,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepTitle,
        if (stepDescription != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.background,
              border: Border.all(color: palette.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: stepDescription!,
          ),
          const SizedBox(height: 20),
        ],
        mainContent,
        if (optionalContents != null) ...[
          const SizedBox(height: 12),
          ...optionalContents!,
        ],
      ],
    );
  }
}
