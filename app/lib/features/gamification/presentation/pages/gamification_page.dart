import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/gamification/data/gamification_remote_datasource.dart';
import 'package:runnin/features/gamification/data/models/badge.dart';
import 'package:runnin/features/gamification/data/models/user_gamification.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/achievement_card.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _GamTab { badges, xp, streak }

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  State<GamificationPage> createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final _gamRemote = GamificationRemoteDatasource();
  final _runRemote = RunRemoteDatasource();
  List<Run>? _runs;
  UserGamification? _gamification;
  List<Badge>? _badges;
  bool _loading = true;
  String? _error;
  _GamTab _tab = _GamTab.xp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _gamRemote.getProfile(),
        _gamRemote.getBadges(),
        _runRemote.listRuns(limit: 200),
      ]);
      if (mounted) setState(() {
        _gamification = results[0] as UserGamification;
        _badges = results[1] as List<Badge>;
        _runs = (results[2] as List<Run>).where((r) => r.status == 'completed').toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: palette.muted),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: 'RUNIN', style: type.displaySm),
                      TextSpan(
                        text: ' .AI',
                        style: type.labelMd.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' / GAMIFICAÇÃO',
                        style: type.labelMd.copyWith(color: palette.muted),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['BADGES', 'XP', 'STREAK'],
                selectedIndex: _GamTab.values.indexOf(_tab),
                onChanged: (i) => setState(() => _tab = _GamTab.values[i]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
                  : _buildTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    final runs = _runs ?? [];
    return switch (_tab) {
      _GamTab.badges => _BadgesTab(runs: runs),
      _GamTab.xp     => _XpTab(runs: runs),
      _GamTab.streak => _StreakTab(runs: runs),
    };
  }
}

// ── XP & Level ───────────────────────────────────────────────────────────────

class _XpTab extends StatelessWidget {
  final List<Run> runs;
  const _XpTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    final level = (totalXp / 500).floor() + 1;
    final xpInLevel = totalXp - (level - 1) * 500;
    final progress = (xpInLevel / 500).clamp(0.0, 1.0);
    final xpToNext = 500 - xpInLevel;

    final rules = [
      ('Completar corrida', '+50–120'),
      ('Atingir pace alvo', '+20'),
      ('Manter streak', '+10/dia'),
      ('Novo badge', '+30'),
      ('Compartilhar card', '+5'),
    ];

    // XP table for each level
    final xpTable = List.generate(10, (i) {
      final lvl = i + 1;
      final xpReq = lvl * 500;
      final isCurrent = lvl == level;
      final isPast = lvl < level;
      return (level: lvl, xpRequired: xpReq, isCurrent: isCurrent, isPast: isPast);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('NÍVEL & XP', style: type.displayMd),
        const SizedBox(height: 16),

        // Level card with progress
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('$level', style: type.dataXl.copyWith(color: palette.primary)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Corredor Nível $level', style: type.labelMd),
                  Text('$xpInLevel / 500 XP · Falta $xpToNext XP', style: type.bodySm),
                ]),
              ]),
              const SizedBox(height: 12),
              ClipRect(
                child: Container(
                  height: 4,
                  color: palette.border,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(color: palette.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metrics
        Row(children: [
          Expanded(child: MetricCard(label: 'XP TOTAL', value: '$totalXp')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'CORRIDAS', value: '${runs.length}')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'NÍVEL', value: '$level', accentColor: palette.primary)),
        ]),
        const SizedBox(height: 20),

        // XP Table
        Text('TABELA DE NÍVEIS', style: type.labelCaps),
        const SizedBox(height: 8),
        AppPanel(
          child: Column(
            children: xpTable.map((row) {
              final color = row.isCurrent
                  ? palette.primary
                  : row.isPast
                      ? palette.text.withValues(alpha: 0.5)
                      : palette.muted;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('Nv ${row.level}', style: type.labelMd.copyWith(color: color)),
                    ),
                    Expanded(
                      child: Text('${row.xpRequired} XP', style: type.bodyMd.copyWith(color: color)),
                    ),
                    if (row.isCurrent)
                      AppTag(label: 'ATUAL', color: palette.primary),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // XP rules
        Text('REGRAS DE XP', style: type.labelCaps),
        const SizedBox(height: 8),
        AppPanel(
          child: Column(
            children: rules.map((rule) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rule.$1, style: type.bodyMd),
                  Text(rule.$2, style: type.labelMd.copyWith(color: palette.primary)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── 21 Badges ───────────────────────────────────────────────────────────────

class _BadgesTab extends StatelessWidget {
  final List<Run> runs;
  const _BadgesTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    final totalKm = runs.fold<double>(0.0, (s, r) => s + r.distanceM) / 1000;

    final badges = <_BadgeDef>[
      // Run count badges
      _BadgeDef(title: 'Primeira Corrida', desc: 'Complete sua primeira corrida', icon: Icons.directions_run, unlocked: runs.isNotEmpty, progress: runs.isNotEmpty ? 1.0 : 0.0),
      _BadgeDef(title: '5 Corridas', desc: 'Complete 5 corridas', icon: Icons.star_outline, unlocked: runs.length >= 5, progress: (runs.length / 5).clamp(0.0, 1.0)),
      _BadgeDef(title: '10 Corridas', desc: 'Complete 10 corridas', icon: Icons.military_tech_outlined, unlocked: runs.length >= 10, progress: (runs.length / 10).clamp(0.0, 1.0)),
      _BadgeDef(title: '25 Corridas', desc: 'Complete 25 corridas', icon: Icons.emoji_events_outlined, unlocked: runs.length >= 25, progress: (runs.length / 25).clamp(0.0, 1.0)),
      _BadgeDef(title: '50 Corridas', desc: 'Complete 50 corridas', icon: Icons.workspace_premium, unlocked: runs.length >= 50, progress: (runs.length / 50).clamp(0.0, 1.0)),
      _BadgeDef(title: '100 Corridas', desc: 'Complete 100 corridas', icon: Icons.auto_awesome, unlocked: runs.length >= 100, progress: (runs.length / 100).clamp(0.0, 1.0)),

      // Distance badges
      _BadgeDef(title: '10 km', desc: 'Acumule 10 km', icon: Icons.route_outlined, unlocked: totalKm >= 10, progress: (totalKm / 10).clamp(0.0, 1.0)),
      _BadgeDef(title: '25 km', desc: 'Acumule 25 km', icon: Icons.terrain_outlined, unlocked: totalKm >= 25, progress: (totalKm / 25).clamp(0.0, 1.0)),
      _BadgeDef(title: '50 km', desc: 'Acumule 50 km', icon: Icons.landscape_outlined, unlocked: totalKm >= 50, progress: (totalKm / 50).clamp(0.0, 1.0)),
      _BadgeDef(title: '100 km', desc: 'Acumule 100 km', icon: Icons.flight_outlined, unlocked: totalKm >= 100, progress: (totalKm / 100).clamp(0.0, 1.0)),
      _BadgeDef(title: '250 km', desc: 'Acumule 250 km', icon: Icons.public_outlined, unlocked: totalKm >= 250, progress: (totalKm / 250).clamp(0.0, 1.0)),
      _BadgeDef(title: '500 km', desc: 'Acumule 500 km', icon: Icons.travel_explore_outlined, unlocked: totalKm >= 500, progress: (totalKm / 500).clamp(0.0, 1.0)),

      // Pace badges
      _BadgeDef(title: 'Sub 6:00', desc: 'Pace médio abaixo de 6:00/km', icon: Icons.speed_outlined, unlocked: runs.any((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 360), progress: runs.isEmpty ? 0.0 : (runs.where((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 360).length / runs.length).clamp(0.0, 1.0)),
      _BadgeDef(title: 'Sub 5:30', desc: 'Pace médio abaixo de 5:30/km', icon: Icons.flash_on_outlined, unlocked: runs.any((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 330), progress: runs.isEmpty ? 0.0 : (runs.where((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 330).length / runs.length).clamp(0.0, 1.0)),
      _BadgeDef(title: 'Sub 5:00', desc: 'Pace médio abaixo de 5:00/km', icon: Icons.bolt_outlined, unlocked: runs.any((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 300), progress: runs.isEmpty ? 0.0 : (runs.where((r) => r.avgPace != null && _paceToSec(r.avgPace!) < 300).length / runs.length).clamp(0.0, 1.0)),

      // Streak badges
      _BadgeDef(title: '3 dias', desc: 'Mantenha streak de 3 dias', icon: Icons.local_fire_department_outlined, unlocked: _maxStreak(runs) >= 3, progress: (_maxStreak(runs) / 3).clamp(0.0, 1.0)),
      _BadgeDef(title: '7 dias', desc: 'Mantenha streak de 7 dias', icon: Icons.whatshot_outlined, unlocked: _maxStreak(runs) >= 7, progress: (_maxStreak(runs) / 7).clamp(0.0, 1.0)),
      _BadgeDef(title: '14 dias', desc: 'Mantenha streak de 14 dias', icon: Icons.fireplace_outlined, unlocked: _maxStreak(runs) >= 14, progress: (_maxStreak(runs) / 14).clamp(0.0, 1.0)),
      _BadgeDef(title: '30 dias', desc: 'Mantenha streak de 30 dias', icon: Icons.local_fire_department, unlocked: _maxStreak(runs) >= 30, progress: (_maxStreak(runs) / 30).clamp(0.0, 1.0)),

      // Special badges
      _BadgeDef(title: 'Madrugador', desc: 'Corra antes das 7h', icon: Icons.wb_twilight, unlocked: runs.any(_isEarlyMorning), progress: runs.any(_isEarlyMorning) ? 1.0 : 0.0),
      _BadgeDef(title: 'Noturno', desc: 'Corra após as 20h', icon: Icons.nights_stay_outlined, unlocked: runs.any((r) { final d = DateTime.tryParse(r.createdAt)?.toLocal(); return d != null && d.hour >= 20; }), progress: runs.any((r) { final d = DateTime.tryParse(r.createdAt)?.toLocal(); return d != null && d.hour >= 20; }) ? 1.0 : 0.0),
      _BadgeDef(title: 'Maratonista', desc: 'Corra mais de 21 km em uma corrida', icon: Icons.emoji_events, unlocked: runs.any((r) => r.distanceM >= 21000), progress: runs.any((r) => r.distanceM >= 21000) ? 1.0 : 0.0),
    ];

    // Split into rows of 3 for a grid
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('BADGES (${badges.where((b) => b.unlocked).length}/${badges.length})', style: type.displayMd),
        const SizedBox(height: 16),
        ...List.generate((badges.length / 3).ceil(), (row) {
          final start = row * 3;
          final rowBadges = badges.sublist(start, (start + 3).clamp(0, badges.length));
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowBadges.map((b) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: rowBadges.indexOf(b) > 0 ? 4 : 0),
                  child: AchievementCard(
                    title: b.title,
                    description: b.desc,
                    icon: b.icon,
                    isUnlocked: b.unlocked,
                    progress: b.progress,
                  ),
                ),
              )).toList(),
            ),
          );
        }),
      ],
    );
  }

  bool _isEarlyMorning(Run r) {
    final d = DateTime.tryParse(r.createdAt)?.toLocal();
    return d != null && d.hour < 7;
  }

  static int _maxStreak(List<Run> runs) {
    if (runs.isEmpty) return 0;
    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet().toList()..sort();

    int best = 1, cur = 1;
    for (int i = 1; i < runDays.length; i++) {
      if (runDays[i].difference(runDays[i - 1]).inDays == 1) {
        cur++;
        best = cur > best ? cur : best;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  static int _paceToSec(String pace) {
    final parts = pace.split(':');
    if (parts.length != 2) return 999;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

class _BadgeDef {
  final String title, desc;
  final IconData icon;
  final bool unlocked;
  final double progress;
  const _BadgeDef({
    required this.title, required this.desc,
    required this.icon, required this.unlocked, required this.progress,
  });
}

// ── Streak ───────────────────────────────────────────────────────────────────

class _StreakTab extends StatelessWidget {
  final List<Run> runs;
  const _StreakTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet();

    // Current streak (consecutive days ending today)
    int streak = 0;
    DateTime day = DateTime.now();
    while (runDays.contains(DateTime(day.year, day.month, day.day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // Best streak
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

    // Calendar
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday;

    // Generate heatmap data for 12 weeks
    final heatmapWeeks = <List<_HeatmapDay>>[];
    for (int w = 11; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + w * 7));
      final week = List.generate(7, (d) {
        final date = weekStart.add(Duration(days: d));
        final hasRun = runDays.contains(date);
        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
        int count = 0;
        if (hasRun) {
          count = runs.where((r) {
            final rd = DateTime.tryParse(r.createdAt)?.toLocal();
            return rd != null &&
                rd.year == date.year &&
                rd.month == date.month &&
                rd.day == date.day;
          }).length;
        }
        return _HeatmapDay(date: date, hasRun: hasRun, count: count, isToday: isToday);
      });
      heatmapWeeks.add(week);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('STREAK', style: type.displayMd),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: MetricCard(label: 'STREAK ATUAL', value: '$streak', unit: 'dias', accentColor: streak > 0 ? palette.primary : null)),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'RECORDE', value: '$best', unit: 'dias')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'DIAS TREINADOS', value: '${runDays.length}')),
        ]),
        const SizedBox(height: 20),

        // Heatmap
        Text('HISTÓRICO (12 SEMANAS)', style: type.labelCaps),
        const SizedBox(height: 12),
        _HeatmapGrid(weeks: heatmapWeeks, palette: palette, type: type),
        const SizedBox(height: 24),

        // Calendar
        Text('${_monthName(now.month)} ${now.year}'.toUpperCase(), style: type.labelCaps),
        const SizedBox(height: 8),
        Row(children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'].map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center, style: type.labelCaps),
        )).toList()),
        const SizedBox(height: 8),
        _CalendarGrid(
          year: now.year, month: now.month,
          daysInMonth: daysInMonth, startWeekday: startWeekday,
          runDays: runDays, today: now,
        ),
      ],
    );
  }
}

class _HeatmapDay {
  final DateTime date;
  final bool hasRun;
  final int count;
  final bool isToday;
  const _HeatmapDay({required this.date, required this.hasRun, required this.count, required this.isToday});
}

class _HeatmapGrid extends StatelessWidget {
  final List<List<_HeatmapDay>> weeks;
  final RunninPalette palette;
  final RunninTypography type;

  const _HeatmapGrid({required this.weeks, required this.palette, required this.type});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels header
          Row(
            children: ['Seg', '', 'Qua', '', 'Sex', '', 'Dom'].map((d) =>
              SizedBox(
                width: 14,
                child: Text(d, style: type.labelCaps.copyWith(fontSize: 8)),
              ),
            ).toList(),
          ),
          const SizedBox(height: 4),
          // Heatmap rows
          ...List.generate(7, (dayOfWeek) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: List.generate(weeks.length, (w) {
                  final day = weeks[w][dayOfWeek];
                  final opacity = day.hasRun
                      ? (0.2 + (day.count / 3).clamp(0.0, 0.8))
                      : 0.05;
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: day.isToday
                          ? palette.primary
                          : palette.primary.withValues(alpha: opacity),
                      border: day.isToday
                          ? Border.all(color: palette.text, width: 1)
                          : null,
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
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
                      width: isToday ? 1.5 : 1,
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
