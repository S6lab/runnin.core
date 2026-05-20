import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Horizontal split row used in the post-run report per
/// `docs/figma/screens/RUN_JOURNEY.md`: KM label + relative time bar +
/// formatted time. Best split renders cyan; others render dim.
class FigmaSplitRow extends StatelessWidget {
  const FigmaSplitRow({
    super.key,
    required this.kmLabel,
    required this.time,
    required this.barRatio, // 0.0–1.0
    this.isBest = false,
    this.bpm,
    this.calories,
    this.elevationGainM,
  });

  final String kmLabel;
  final String time;
  final double barRatio;
  final bool isBest;
  /// FC média (bpm) do km. Quando presente, renderiza chip dim abaixo do
  /// pace. Persistido em Run.splits[].avgBpm pelo complete-run.
  final int? bpm;
  /// Calorias estimadas (kcal) do km — computado server-side via MET ×
  /// peso × tempo do km. Quando presente, renderiza ao lado do bpm.
  final int? calories;
  /// Ganho de elevação (m) do km — soma de deltas+ de altitude. Renderiza
  /// como `+12m` na linha meta abaixo do pace.
  final double? elevationGainM;

  @override
  Widget build(BuildContext context) {
    final barColor = isBest ? context.runninPalette.primary : FigmaColors.textDim;
    final hasMeta = bpm != null || calories != null || elevationGainM != null;
    final mainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            kmLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: FigmaColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                color: FigmaColors.progressTrack,
              ),
              FractionallySizedBox(
                widthFactor: barRatio.clamp(0.0, 1.0),
                child: Container(height: 8, color: barColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            time,
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 19.5 / 13,
              fontWeight: FontWeight.w500,
              color: isBest ? context.runninPalette.primary : FigmaColors.textPrimary,
            ),
          ),
        ),
      ],
    );

    if (!hasMeta) return mainRow;

    final metaParts = <String>[
      if (bpm != null) '${bpm}bpm',
      if (calories != null) '${calories}kcal',
      if (elevationGainM != null) '+${elevationGainM!.toStringAsFixed(elevationGainM! >= 10 ? 0 : 1)}m',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mainRow,
        Padding(
          padding: const EdgeInsets.only(left: 54, top: 2),
          child: Text(
            metaParts.join(' · '),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              color: FigmaColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
