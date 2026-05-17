import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Period selector usado em HIST DADOS (SEMANA / MÊS / 3 MESES) — tela 30.
/// 3 abas cyan-border, ativo cheio cyan.
enum HistPeriod { week, month, threeMonths }

class FigmaPeriodSelector extends StatelessWidget {
  const FigmaPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HistPeriod value;
  final ValueChanged<HistPeriod> onChanged;

  static const _labels = {
    HistPeriod.week: 'SEMANA',
    HistPeriod.month: 'MÊS',
    HistPeriod.threeMonths: '3 MESES',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Row(
        children: HistPeriod.values
            .map((p) => Expanded(child: _Tab(
                  label: _labels[p]!,
                  active: p == value,
                  onTap: () => onChanged(p),
                )))
            .toList(),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        color: active ? FigmaColors.brandCyan : Colors.transparent,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: active ? FigmaColors.bgBase : FigmaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
