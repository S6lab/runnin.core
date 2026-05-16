import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/run_feedback.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final RunFeedback report;

  String get title => report.run.type.toUpperCase();

  String get dateLabel {
    final parsed = DateTime.tryParse(report.run.createdAt);
    if (parsed == null) return '--/--';
    return DateFormat('dd/MM').format(parsed.toLocal());
  }

  double get totalKm => report.run.distanceM / 1000;

  String get durationLabel => _formatDuration(report.run.durationS);

  String get paceLabel => report.run.avgPace ?? '--:--';

  String get coachSummary => report.summary;

  String _formatDuration(int durationS) {
    final minutes = durationS ~/ 60;
    final seconds = durationS % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      color: report.isLatest ? palette.surfaceAlt : null,
      borderColor: report.isLatest
          ? palette.primary.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: palette.text,
                  ),
                ),
              ),
              if (report.isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  color: palette.primary,
                  child: Text(
                    'MAIS RECENTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: palette.background,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricColumn(label: 'DATA', value: dateLabel),
              ),
              Expanded(
                child: _MetricColumn(label: 'KM', value: totalKm.toStringAsFixed(2)),
              ),
              Expanded(
                child: _MetricColumn(label: 'TEMPO', value: durationLabel),
              ),
              Expanded(
                child: _MetricColumn(label: 'PACE', value: paceLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
 coachSummary,
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          AppTag(label: 'RELATORIO REAL', color: palette.primary),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: palette.secondary,
          ),
        ),
      ],
    );
  }
}

class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: color,
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
