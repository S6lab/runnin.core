import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_chart_line_spark.dart';

enum ShareTheme { dark, color, minimal }

class FigmaShareCardPreview extends StatelessWidget {
  const FigmaShareCardPreview({
    super.key,
    required this.run,
    required this.theme,
    this.skinAccent,
  });

  final Run run;
  final ShareTheme theme;
  final Color? skinAccent;

  Color get _bg {
    switch (theme) {
      case ShareTheme.dark:
        return FigmaColors.bgBase;
      case ShareTheme.color:
        return const Color(0xFF0A1628);
      case ShareTheme.minimal:
        return Colors.black;
    }
  }

  Color get _accent {
    switch (theme) {
      case ShareTheme.dark:
        return FigmaColors.brandCyan;
      case ShareTheme.color:
        return skinAccent ?? FigmaColors.brandCyan;
      case ShareTheme.minimal:
        return Colors.white;
    }
  }

  Color get _textMain {
    switch (theme) {
      case ShareTheme.dark:
      case ShareTheme.color:
        return FigmaColors.textPrimary;
      case ShareTheme.minimal:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distKm = (run.distanceM / 1000).toStringAsFixed(1);
    final duration = _fmtDuration(run.durationS);
    final pace = run.avgPace ?? '--:--';

    final splitValues = _generateSplitValues();

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _accent.withValues(alpha: 0.2), width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branding badge
            Text(
              'RUNNIN.AI',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _accent,
              ),
            ),
            const Spacer(flex: 1),

            // Distance large
            Text(
              '${distKm}km',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: _textMain,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),

            // Duration + pace row
            Row(
              children: [
                Text(
                  duration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.brandOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Pace: $pace/km',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _textMain.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sparkline
            SizedBox(
              height: 60,
              child: FigmaChartLineSpark(
                values: splitValues,
                height: 60,
                lineColor: _accent,
              ),
            ),
            const SizedBox(height: 8),

            // Km markers
            if (splitValues.length >= 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  splitValues.length.clamp(0, 5),
                  (i) => Text(
                    '${i + 1}K',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _textMain.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

            const Spacer(flex: 1),

            // Tagline
            Text(
              _buildTagline(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _textMain.withValues(alpha: 0.6),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Stats footer
            Row(
              children: [
                if (run.avgBpm != null)
                  _StatChip(label: '${run.avgBpm} BPM', color: _accent),
                if (run.xpEarned != null && run.xpEarned! > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(label: '+${run.xpEarned} XP', color: _accent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<double> _generateSplitValues() {
    final km = run.distanceM / 1000;
    final splits = km.floor().clamp(2, 10);
    final basePace = run.durationS / km;
    return List.generate(splits, (i) {
      final variation = (i.isEven ? 1.02 : 0.98) + (i * 0.005);
      return basePace * variation;
    });
  }

  String _buildTagline() {
    final type = run.type.isNotEmpty ? run.type : 'corrida';
    return 'Corrida $type concluída';
  }

  static String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
