import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Tabs em caps com seleção preenchida na cor primária.
/// Usado em training, history e gamification.
class SegmentedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  /// Tamanho da fonte das tabs.
  final double fontSize;
  /// Quando true, a tab selecionada fica só com CONTORNO (sem preencher o
  /// fundo) e o texto na cor primária. Default = preenchido na primária.
  final bool outlineSelection;

  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 11,
    this.outlineSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border, width: 1.041),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selectedIndex;
          final Color textColor = isSelected
              ? (outlineSelection ? palette.primary : palette.background)
              : palette.muted;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  // Preenchido (default) muda o fundo; outline só desenha a
                  // borda na cor primária, mantendo o fundo transparente.
                  color: (!outlineSelection && isSelected)
                      ? palette.primary
                      : Colors.transparent,
                  border: (outlineSelection && isSelected)
                      ? Border.all(color: palette.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i].toUpperCase(),
                  style: type.labelCaps.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: fontSize,
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
