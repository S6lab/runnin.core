import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Seletor visual de skin no perfil.
/// Exibe preview com 3 barras de cor (primary/secondary/tertiary).
class PaletteCard extends StatelessWidget {
  final RunninSkin skin;
  final bool isSelected;
  final VoidCallback onTap;

  const PaletteCard({
    super.key,
    required this.skin,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final skinPalette = skin.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: skinPalette.surface,
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview de cores
            Row(
              children: skinPalette.previewBars.map((c) => Expanded(
                child: Container(height: 4, color: c, margin: const EdgeInsets.symmetric(horizontal: 1)),
              )).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              skinPalette.label.toUpperCase(),
              style: type.labelCaps.copyWith(
                color: isSelected ? palette.primary : palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text('ATIVO', style: type.labelCaps.copyWith(color: palette.primary, fontSize: 8)),
            ],
          ],
        ),
      ),
    );
  }
}
