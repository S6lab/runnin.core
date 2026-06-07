import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Per-zone card for PERFIL > SAÚDE > ZONAS per `docs/figma/screens/PERFIL.md`.
/// Shows zone color swatch, label (e.g. "Z1 — Recuperação"), BPM range,
/// % of time, and a thick 7.997 px progress bar.
class FigmaZoneCard extends StatelessWidget {
  const FigmaZoneCard({
    super.key,
    required this.zoneNumber,
    required this.zoneLabel,
    required this.bpmRange,
    required this.percent,
    required this.zoneColor,
  });

  final int zoneNumber; // 1..5
  final String zoneLabel; // e.g. "Recuperação"
  final String bpmRange; // e.g. "98-118"
  final double percent; // 0..100
  final Color zoneColor;

  @override
  Widget build(BuildContext context) {
    // Antes era altura FIXA de 58.937 do Figma — fontes do Google Fonts
    // (jetBrainsMono) com line-height 19.5/13 + 16.5/11 + paddings estouravam
    // por ~2-3pt em todas as zonas, e Z3 estourava em 167pt (LinearProgress
    // não respeitava constraint vertical sem altura clamp). Usar
    // constraints.minHeight deixa crescer naturalmente quando necessário e
    // mantém o visual baseline do Figma quando o conteúdo cabe.
    return Container(
      constraints: const BoxConstraints(minHeight: 58.937),
      padding: const EdgeInsets.symmetric(horizontal: 13.718, vertical: 10),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            color: zoneColor,
            child: Text(
              'Z$zoneNumber',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: FigmaColors.bgBase,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  zoneLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    height: 19.5 / 13,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Defensive: alguns call sites já passam "X-Y bpm" no
                  // bpmRange (historico) e outros só "X-Y" (perfil/saude).
                  // Detecta sufixo "bpm" pra não duplicar.
                  bpmRange.trim().toLowerCase().endsWith('bpm')
                      ? bpmRange
                      : '$bpmRange bpm',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 16.5 / 11,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: zoneColor,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 7.997,
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: FigmaColors.progressTrack,
                    valueColor: AlwaysStoppedAnimation(zoneColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
