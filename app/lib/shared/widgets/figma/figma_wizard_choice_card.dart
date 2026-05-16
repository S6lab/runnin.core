import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Card de escolha em wizards estruturados (Coach Revision Flow tela 24).
/// Mostra ícone (opcional) + título grande + subtitle pequeno.
/// Estado selected adiciona cyan border + bg sutil.
class FigmaWizardChoiceCard extends StatelessWidget {
  const FigmaWizardChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.iconLabel,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  /// Label tipográfico em vez de icon (ex: "↑", "+", "−", "⚡")
  final String? iconLabel;

  /// Material icon alternativo
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: selected
              ? FigmaColors.selectionActiveBg
              : FigmaColors.surfaceCard,
          border: Border.all(
            color: selected
                ? FigmaColors.selectionActiveBorder
                : FigmaColors.borderDefault,
            width: 1.041,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconLabel != null)
              Text(
                iconLabel!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textSecondary,
                  height: 1.2,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 18, color: FigmaColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 19.5 / 13,
                color: FigmaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: FigmaColors.textMuted,
                height: 16.5 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-reply button usado no Coach Chat (sub-options pós choice). Mais
/// compacto que `FigmaWizardChoiceCard`. Per mockup tela 26.
class FigmaQuickReplyButton extends StatelessWidget {
  const FigmaQuickReplyButton({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected
              ? FigmaColors.brandOrange.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: FigmaColors.brandOrange.withValues(alpha: selected ? 0.7 : 0.35),
            width: 1.041,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
