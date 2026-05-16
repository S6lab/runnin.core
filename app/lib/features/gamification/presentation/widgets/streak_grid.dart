import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'streak_card.dart';

class StreakGrid extends StatelessWidget {
  final List<Run> runs;
  const StreakGrid({
    super.key,
    required this.runs,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet();

    final streak = StreakGrid.countStreak(runs);
    final best = StreakGrid.countBestStreak(runDays);

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('STREAK', style: type.displayMd),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: StreakCard(
            label: 'STREAK ATUAL',
            value: '$streak',
            unit: 'dias',
            accentColor: streak > 0 ? palette.primary : Colors.transparent,
          )),
          const SizedBox(width: 8),
          Expanded(child: StreakCard(label: 'RECORDE', value: '$best', unit: 'dias')),
          const SizedBox(width: 8),
          Expanded(child: StreakCard(label: 'DIAS TREINADOS', value: '${runDays.length}')),
        ]),
        const SizedBox(height: 20),
        Text(
          '${_monthName(now.month)} ${now.year}'.toUpperCase(),
          style: type.labelCaps,
        ),
        const SizedBox(height: 8),
        Row(children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'].map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center, style: type.labelCaps),
        )).toList()),
        const SizedBox(height: 8),
        _CalendarGrid(
          year: now.year,
          month: now.month,
          daysInMonth: daysInMonth,
          startWeekday: startWeekday,
          runDays: runDays,
          today: now,
        ),
      ],
    );
  }

  static int countStreak(List<Run> runs) {
    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet();

    int streak = 0;
    DateTime day = DateTime.now();
    while (runDays.contains(DateTime(day.year, day.month, day.day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int countBestStreak(Set<DateTime> runDays) {
    int best = 0, cur = 0;
    final sorted = runDays.toList()..sort();
    DateTime? prev;
    for (final d in sorted) {
      if (prev != null && d.difference(prev).inDays == 1) {
        cur++;
      } else {
        cur = 1;
      }
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }
}

class _CalendarGrid extends StatelessWidget {
  final int year, month, daysInMonth, startWeekday;
  final Set<DateTime> runDays;
  final DateTime today;

  const _CalendarGrid({
    required this.year, required this.month, required this.daysInMonth,
    required this.startWeekday, required this.runDays, required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final cells = (startWeekday - 1) + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - (startWeekday - 1) + 1;
            if (dayNum < 1 || dayNum > daysInMonth) return const Expanded(child: SizedBox());

            final date = DateTime(year, month, dayNum);
            final hasRun = runDays.contains(date);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            return Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasRun
                        ? palette.primary.withValues(alpha: 0.2)
                        : palette.surface,
                    border: Border.all(
                      color: isToday ? palette.primary : palette.border,
                      width: 1.735,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: type.labelCaps.copyWith(
                          fontSize: 10,
                          color: hasRun ? palette.primary : palette.muted,
                          fontWeight: hasRun ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      if (hasRun)
                        Container(width: 4, height: 4, color: palette.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      )),
    );
  }
}

String _monthName(int month) {
  const names = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  return names[month];
}
