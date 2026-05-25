import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';

/// BottomSheet de pre-submit. Mostra a issue principal + lista de
/// AdmissibilitySuggestion clicáveis. Cada tap chama `onPick(suggestion)`
/// no parent, que muta o state do wizard + navega pra step relevante +
/// re-submete se aplicável.
class AdmissibilitySheet extends StatelessWidget {
  final AdmissibilityResult result;
  final ValueChanged<AdmissibilitySuggestion> onPick;

  const AdmissibilitySheet({super.key, required this.result, required this.onPick});

  static Future<void> show(
    BuildContext context, {
    required AdmissibilityResult result,
    required ValueChanged<AdmissibilitySuggestion> onPick,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdmissibilitySheet(result: result, onPick: onPick),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final primary = result.issues.first;
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: palette.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VAMOS AJUSTAR ANTES DE GERAR',
                  style: type.labelMd.copyWith(color: palette.warning, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primary.explanation,
            style: type.bodyMd.copyWith(color: palette.text, height: 1.5),
          ),
          const SizedBox(height: 18),
          for (final s in result.suggestions) ...[
            _SuggestionTile(
              suggestion: s,
              palette: palette,
              type: type,
              onTap: () {
                Navigator.of(context).pop();
                onPick(s);
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.border),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                'VOLTAR E AJUSTAR MANUALMENTE',
                style: type.labelMd.copyWith(color: palette.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final AdmissibilitySuggestion suggestion;
  final RunninPalette palette;
  final RunninTypography type;
  final VoidCallback onTap;
  const _SuggestionTile({
    required this.suggestion,
    required this.palette,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 16, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.label,
                    style: type.labelMd.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.subtitle,
                    style: type.bodySm.copyWith(color: palette.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
