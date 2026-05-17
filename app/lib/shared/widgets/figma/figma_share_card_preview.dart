import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
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

  Color _bg(RunninPalette palette) {
    switch (theme) {
      case ShareTheme.dark:
        return palette.background;
      case ShareTheme.color:
        return Color.lerp(palette.background, palette.primary, 0.06)!;
      case ShareTheme.minimal:
        return Colors.black;
    }
  }

  Color _accent(RunninPalette palette) {
    switch (theme) {
      case ShareTheme.dark:
      case ShareTheme.color:
        return skinAccent ?? palette.primary;
      case ShareTheme.minimal:
        return Colors.white;
    }
  }

  Color _textMain(RunninPalette palette) {
    switch (theme) {
      case ShareTheme.dark:
      case ShareTheme.color:
        return palette.text;
      case ShareTheme.minimal:
        return Colors.white;
    }
  }

  Color _accentSecondary(RunninPalette palette) {
    switch (theme) {
      case ShareTheme.dark:
      case ShareTheme.color:
        return palette.secondary;
      case ShareTheme.minimal:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final bg = _bg(palette);
    final accent = _accent(palette);
    final textMain = _textMain(palette);
    final accentSecondary = _accentSecondary(palette);
    final distKm = (run.distanceM / 1000).toStringAsFixed(1);
    final duration = _fmtDuration(run.durationS);
    final pace = run.avgPace ?? '--:--';

    final splitValues = _generateSplitValues();

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
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
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                color: accent,
              ),
            ),
            const Spacer(flex: 1),

            // Distance large
            Text(
              '${distKm}km',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 48,
                fontWeight: FontWeight.w500,
                color: textMain,
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
                    color: accentSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Pace: $pace/km',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textMain.withValues(alpha: 0.7),
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
                lineColor: accent,
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
                      color: textMain.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

            const Spacer(flex: 1),

            // Stats footer
            Row(
              children: [
                if (run.avgBpm != null)
                  _StatChip(label: '${run.avgBpm} BPM', color: accent),
                if (run.xpEarned != null && run.xpEarned! > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(label: '+${run.xpEarned} XP', color: accent),
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
