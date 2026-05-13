import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/share_helper.dart';

class RunShareCardData {
  final String distance;
  final String duration;
  final String pace;
  final String? targetPace;
  final String? targetDistance;
  final String runType;
  final int? xpEarned;
  final String? coachSummary;

  const RunShareCardData({
    required this.distance,
    required this.duration,
    required this.pace,
    this.targetPace,
    this.targetDistance,
    required this.runType,
    this.xpEarned,
    this.coachSummary,
  });
}

class RunShareCard extends StatelessWidget {
  final RunShareCardData data;
  final RunninPalette palette;
  final RunninTypography typography;
  final double scale;

  const RunShareCard({
    super.key,
    required this.data,
    required this.palette,
    required this.typography,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 480,
        height: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.background,
          border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'RUNIN.AI',
                  style: typography.labelCaps.copyWith(
                    color: palette.primary,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    data.runType.toUpperCase(),
                    style: typography.labelCaps.copyWith(
                      color: palette.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.distance,
                  style: typography.dataXl.copyWith(fontSize: 48, height: 1.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 6),
                  child: Text(
                    'km',
                    style: typography.labelCaps.copyWith(
                      color: palette.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _MiniStat(
                  label: 'DURACAO',
                  value: data.duration,
                  palette: palette,
                  typography: typography,
                ),
                const SizedBox(width: 24),
                _MiniStat(
                  label: 'PACE',
                  value: '${data.pace}/km',
                  palette: palette,
                  typography: typography,
                ),
                if (data.xpEarned != null && data.xpEarned! > 0) ...[
                  const SizedBox(width: 24),
                  _MiniStat(
                    label: 'XP',
                    value: '+${data.xpEarned}',
                    palette: palette,
                    typography: typography,
                  ),
                ],
              ],
            ),
            const Spacer(),
            if (data.coachSummary != null && data.coachSummary!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  border: Border(
                    left: BorderSide(color: palette.secondary, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: palette.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.coachSummary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final RunninPalette palette;
  final RunninTypography typography;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.palette,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: typography.labelCaps.copyWith(
            color: palette.muted,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: typography.dataSm.copyWith(
            color: palette.text,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

String buildShareText(RunShareCardData data) {
  final buf = StringBuffer();
  buf.writeln('${data.runType}');
  buf.writeln('━━━━━━━━━━━━━━━');
  buf.writeln('${data.distance} km  ·  ${data.duration}');
  buf.writeln('${data.pace}/km');
  if (data.xpEarned != null && data.xpEarned! > 0) {
    buf.writeln('+${data.xpEarned} XP');
  }
  if (data.coachSummary != null && data.coachSummary!.isNotEmpty) {
    buf.writeln('');
    buf.writeln('${data.coachSummary}');
  }
  buf.writeln('');
  buf.writeln('via runin.ai');
  return buf.toString();
}

Future<void> shareRunResult(RunShareCardData data) async {
  await shareText(buildShareText(data));
}
