import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Inline option button rendered inside a Coach chat bubble per
/// `docs/figma/screens/TREINO.md` §"Botões de opção" (TREINO Coach Chat 2)
/// and §"Botões de ação" (Coach Chat 3 confirmation buttons).
///
/// Three accent variants:
///   - [CoachOptionAccent.orange] (default) — Coach suggestions
///   - [CoachOptionAccent.cyan] — primary confirmation actions
///   - [CoachOptionAccent.neutral] — secondary cancel actions
enum CoachOptionAccent { orange, cyan, neutral }

class FigmaCoachOptionButton extends StatelessWidget {
  const FigmaCoachOptionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = CoachOptionAccent.orange,
  });

  final String label;
  final VoidCallback onTap;
  final CoachOptionAccent accent;

  @override
  Widget build(BuildContext context) {
    final colors = switch (accent) {
      CoachOptionAccent.orange => (
          bg: const Color(0x08FF6B35), // rgba(255,107,53,0.03)
          border: const Color(0x24FF6B35), // rgba(255,107,53,0.14)
          text: FigmaColors.textPrimary,
        ),
      CoachOptionAccent.cyan => (
          bg: const Color(0x1400D4FF), // rgba(0,212,255,0.08)
          border: FigmaColors.brandCyan,
          text: FigmaColors.brandCyan,
        ),
      CoachOptionAccent.neutral => (
          bg: Colors.transparent,
          border: const Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
          text: FigmaColors.textSecondary,
        ),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 47.415,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 11.98),
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border.all(color: colors.border, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            height: 18 / 12,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
      ),
    );
  }
}
