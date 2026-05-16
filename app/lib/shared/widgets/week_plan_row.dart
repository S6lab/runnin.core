import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class WeekPlanRow extends StatelessWidget {
  const WeekPlanRow({
    super.key,
    required this.dayOfWeek,
    required this.session,
    required this.isToday,
    required this.isDone,
  });

  final int dayOfWeek;
  final PlanSession? session;
  final bool isToday;
  final bool isDone;

  static const _dayNames = [
    '',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  String _distanceLabel(PlanSession session) {
    if (session.type.toLowerCase().contains('interval')) {
      return '${session.distanceKm.toStringAsFixed(1)}K';
    }
    if (session.distanceKm == session.distanceKm.truncateToDouble()) {
      return '${session.distanceKm.toStringAsFixed(0)}K';
    }
    return '${session.distanceKm.toStringAsFixed(1)}K';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final isRest = session == null;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      color: isToday ? palette.surfaceAlt : palette.surface,
      borderColor: isToday
          ? palette.primary.withValues(alpha: 0.4)
          : palette.border,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            color: isDone
                ? palette.primary
                : isToday
                    ? palette.primary.withValues(alpha: 0.15)
                    : palette.surfaceAlt,
            child: Text(
              isDone
                  ? 'OK'
                  : (isToday
                      ? 'HOJE'
                      : _dayNames[dayOfWeek].substring(0, 3).toUpperCase()),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isDone
                    ? palette.background
                    : (isToday ? palette.primary : palette.muted),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayNames[dayOfWeek],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRest ? 'Descanso' : session!.type,
                  style: TextStyle(color: palette.muted),
                ),
              ],
            ),
          ),
          if (!isRest)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _distanceLabel(session!),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: palette.secondary,
                  ),
                ),
                if (session!.targetPace != null)
                  Text(
                    session!.targetPace!,
                    style: TextStyle(color: palette.muted),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
