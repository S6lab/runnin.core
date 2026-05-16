import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class RunCard extends StatelessWidget {
  final Run run;
  const RunCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    return FigmaRunCard(
      typeLabel: run.type.toUpperCase(),
      dateLabel: _fmtDate(run.createdAt),
      distanceKm: run.distanceM / 1000,
      pace: run.avgPace ?? '--:--',
      duration: _fmtDuration(run.durationS),
      coachPreview: run.type,
      onTap: () => context.push('/report', extra: run.id),
    );
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd/MM').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
