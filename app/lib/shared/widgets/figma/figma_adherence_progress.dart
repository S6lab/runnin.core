import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Card de aderência ao plano (Weekly Report Detail tela 23).
/// - percent 0-100
/// - cor adaptativa: cyan ≥ 70, orange < 70
/// - badge "ATENÇÃO" laranja quando < 70
class FigmaAdherenceProgress extends StatelessWidget {
  const FigmaAdherenceProgress({
    super.key,
    required this.percent,
    required this.sessionsDone,
    required this.sessionsPlanned,
  });

  final int percent;
  final int sessionsDone;
  final int sessionsPlanned;

  @override
  Widget build(BuildContext context) {
    final low = percent < 70;
    final color = low ? FigmaColors.brandOrange : FigmaColors.brandCyan;

    return Container(
      padding: const EdgeInsets.all(13.718),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ADERÊNCIA AO PLANO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ),
              if (low)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: FigmaColors.brandOrange,
                  child: Text(
                    'ATENÇÃO',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: FigmaColors.bgBase,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: color,
                ),
              ),
              Text(
                ' %',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 7.997,
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              backgroundColor: FigmaColors.progressTrack,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$sessionsDone/$sessionsPlanned sessões concluídas',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
