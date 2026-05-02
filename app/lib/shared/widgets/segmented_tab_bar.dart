import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Tabs em caps com seleção preenchida na cor primária.
/// Usado em training, history e gamification.
class SegmentedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: isSelected ? palette.primary : Colors.transparent,
                alignment: Alignment.center,
                child: Text(
                  tabs[i].toUpperCase(),
                  style: type.labelCaps.copyWith(
                    color: isSelected ? palette.background : palette.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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
