import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Stat tile com label + valor grande + delta cor-codificado vs período anterior.
/// Usado em HIST DADOS §EVOLUÇÃO RESUMO (tela 30): PACE -25s↗ verde, BPM +2↑
/// vermelho, etc. Cor do delta deriva de [deltaIsPositive].
class FigmaStatTileWithDelta extends StatelessWidget {
  const FigmaStatTileWithDelta({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.delta,
    required this.deltaIsPositive,
    this.deltaLabel,
  });

  final String label;
  final String value;
  final String? unit;

  /// Texto do delta (ex: "-25s", "+8.6km", "+2", "+8%"). Sinal e magnitude.
  final String delta;

  /// True quando o delta representa melhora (verde). False = piora (vermelho).
  /// Pace ↓ é positive, BPM ↓ é positive em repouso, etc — caller decide.
  final bool deltaIsPositive;

  /// Subtext opcional abaixo do delta (ex: "vs período anterior", "6:20 → 5:55").
  final String? deltaLabel;

  @override
  Widget build(BuildContext context) {
    final deltaColor = deltaIsPositive
        ? const Color(0xFF22C55E) // verde
        : FigmaColors.brandOrange; // laranja/vermelho para piora

    return Container(
      padding: const EdgeInsets.all(13.718),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border(
          left: BorderSide(color: deltaColor, width: 1.041),
          top: BorderSide(color: FigmaColors.borderDefault, width: 1.041),
          right: BorderSide(color: FigmaColors.borderDefault, width: 1.041),
          bottom: BorderSide(color: FigmaColors.borderDefault, width: 1.041),
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                delta,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  color: deltaColor,
                ),
              ),
              Text(
                ' ${deltaIsPositive ? '↗' : '↘'}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: deltaColor,
                ),
              ),
            ],
          ),
          if (unit != null) ...[
            const SizedBox(height: 2),
            Text(
              unit!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: FigmaColors.textMuted,
              ),
            ),
          ],
          if (deltaLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              deltaLabel!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: FigmaColors.textSecondary,
                height: 14 / 10,
              ),
            ),
          ],
          // Valor absoluto (referência), pequeno, abaixo
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textGhost,
            ),
          ),
        ],
      ),
    );
  }
}
