import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Tab bar widget following Figma design system
/// Height: 41.424px, tab width: 115.298px
class FigmaTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const FigmaTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    const double navHeight = 41.424;

    return SizedBox(
      height: navHeight,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.zero,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: context.runninType.labelMd.copyWith(
                    color: isSelected ? palette.primary : palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
