import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class TabBarWidget extends StatelessWidget {
  final List<TabData> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final TabBarAppearance appearance;

  const TabBarWidget({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.appearance = const TabBarAppearance(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: appearance.borderColor ?? palette.border),
        borderRadius: BorderRadius.circular(appearance.borderRadius ?? 8),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: appearance.padding?.vertical ?? 10,
                  horizontal: appearance.padding?.horizontal ?? 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primary
                      : Colors.transparent,
                  borderRadius: i == 0
                      ? BorderRadius.only(
                          topLeft: Radius.circular(appearance.borderRadius ?? 8),
                          bottomLeft: Radius.circular(appearance.borderRadius ?? 8),
                        )
                      : i == tabs.length - 1
                          ? BorderRadius.only(
                              topRight: Radius.circular(appearance.borderRadius ?? 8),
                              bottomRight: Radius.circular(appearance.borderRadius ?? 8),
                            )
                          : BorderRadius.zero,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i].label.toUpperCase(),
                  style: type.labelCaps.copyWith(
                    color: isSelected
                        ? palette.background
                        : (appearance.inactiveColor ?? palette.muted),
                    fontWeight: FontWeight.w700,
                    fontSize: appearance.fontSize ?? 11,
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

class TabData {
  final String label;
  final Widget? icon;

  const TabData({
    required this.label,
    this.icon,
  });
}

class TabBarAppearance {
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? inactiveColor;
  final double? fontSize;

  const TabBarAppearance({
    this.borderColor,
    this.borderRadius,
    this.padding,
    this.inactiveColor,
    this.fontSize,
  });
}
