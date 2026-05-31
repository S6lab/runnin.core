import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Snapshot do estado atual do atleta, em campos editáveis. Os defaults
/// vêm do /stats/breakdown (último mês) quando há histórico — o user
/// confirma ou ajusta. "Não sei" envia null e o LLM trata.
class PlanStepCurrentLoad extends StatefulWidget {
  final TextEditingController paceController;
  final TextEditingController weeklyKmController;
  final String? hintFromHistory;
  final VoidCallback? onSkip;
  final bool skipped;

  const PlanStepCurrentLoad({
    super.key,
    required this.paceController,
    required this.weeklyKmController,
    this.hintFromHistory,
    this.onSkip,
    this.skipped = false,
  });

  @override
  State<PlanStepCurrentLoad> createState() => _PlanStepCurrentLoadState();
}

class _PlanStepCurrentLoadState extends State<PlanStepCurrentLoad> {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final disabled = widget.skipped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// CARGA ATUAL'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Como você está correndo hoje?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'O coach usa esses números pra calibrar a semana 1 sem te assustar nem te subestimar.',
        ),
        if (widget.hintFromHistory != null && !widget.skipped) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.08),
              border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.hintFromHistory!,
                    style: context.runninType.bodySm.copyWith(
                      color: palette.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        _LabeledField(
          label: 'PACE CONFORTÁVEL',
          hint: '6:30 (min:seg / km)',
          controller: widget.paceController,
          enabled: !disabled,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'KM POR SEMANA (média atual)',
          hint: '18',
          controller: widget.weeklyKmController,
          enabled: !disabled,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: widget.onSkip,
          child: Row(
            children: [
              Icon(
                widget.skipped ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: widget.skipped ? palette.primary : palette.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Não sei — deixa o coach calibrar pelos meus dados.',
                  style: context.runninType.bodySm.copyWith(
                    color: widget.skipped ? palette.primary : palette.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool enabled;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: context.runninType.bodyMd.copyWith(color: palette.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.runninType.bodyMd.copyWith(
              color: palette.muted.withValues(alpha: 0.6),
            ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border, width: 1.041),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border, width: 1.041),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.primary, width: 1.041),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ],
    );
  }
}
