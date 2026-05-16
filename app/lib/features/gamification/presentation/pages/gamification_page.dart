import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/achievement_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _GamTab { badges, xp, streak }

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  State<GamificationPage> createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _runs;
  bool _loading = true;
  _GamTab _tab = _GamTab.xp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await _remote.listRuns(limit: 90);
      if (mounted) setState(() { _runs = runs.where((r) => r.status == 'completed').toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
            const FigmaTopNav(
              breadcrumb: 'Perfil / Gamificação',
              showBackButton: true,
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

  int _countUnlockedBadges(List<Run> runs) {
    final unlocked = <bool>[];
    
    unlocked.add(runs.isNotEmpty);
    unlocked.add(runs.length >= 5);
    unlocked.add(_countStreak(runs) >= 7);
    unlocked.add(_countStreak(runs) >= 14);
    unlocked.add(_hasPaceBelow(runs, 6.0));
    unlocked.add(_hasPaceBelow(runs, 5.5));
    unlocked.add(_isTop20Percent(runs));
    unlocked.add(runs.any(_isZona));
    unlocked.add(runs.any(_isNoturno));
    unlocked.add(runs.any(_isIntervalado));
    unlocked.add(_hasLongRun(runs, 21));
    unlocked.add(runs.length >= 10);
    unlocked.add(runs.any(_isSocialRun));
    unlocked.add(_hasFastRecovery(runs));
    unlocked.add(runs.any(_hasHillRun));
    unlocked.add(_isPerfectMonth(runs));
    unlocked.add(runs.length >= 21);
    unlocked.add(_isLabRat(runs));
    
    return unlocked.where((b) => b).length;
  }

  int _countStreak(List<Run> runs) {
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

  bool _hasPaceBelow(List<Run> runs, double targetMinPerKm) {
    for (final r in runs) {
      if (r.distanceM > 0 && r.elapsedSeconds != null) {
        final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
        if (pace < targetMinPerKm) return true;
      }
    }
    return false;
  }

  bool _isTop20Percent(List<Run> runs) {
    if (runs.length < 5) return false;
    final sorted = List.of(runs)..sort((a, b) {
      final distA = a.distanceM;
      final distB = b.distanceM;
      return distB.compareTo(distA);
    });
    final index20Percent = (sorted.length * 0.2).floor();
    return runs.contains(sorted[index20Percent]);
  }

  bool _isZona(Run r) {
    final d = DateTime.tryParse(r.createdAt)?.toLocal();
    return d != null && (d.hour >= 17 && d.hour < 21);
  }

  bool _isNoturno(Run r) {
    final d = DateTime.tryParse(r.createdAt)?.toLocal();
    return d != null && (d.hour >= 21 || d.hour < 6);
  }

  bool _isIntervalado(Run r) {
    return (r.distanceM >= 5000 && r.elapsedSeconds != null && r.elapsedSeconds! > 1800) ||
           (r.distanceM >= 10000 && r.elapsedSeconds != null && r.elapsedSeconds! > 3600);
  }

  bool _hasLongRun(List<Run> runs, double minKm) {
    return runs.any((r) => r.distanceM >= minKm * 1000);
  }

  bool _isSocialRun(Run r) {
    return (r.distanceM >= 5000 && r.elapsedSeconds == null) ||
           (r.distanceM < 5000 && r.distanceM > 0);
  }

  bool _hasFastRecovery(List<Run> runs) {
    for (final r in runs) {
      if (r.distanceM >= 10000 && r.elapsedSeconds != null) {
        final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
        if (pace < 5.0) return true;
      }
    }
    return false;
  }

  bool _hasHillRun(Run r) {
    return r.elevationGain != null && r.elevationGain! > 100;
  }

  bool _isPerfectMonth(List<Run> runs) {
    final now = DateTime.now();
    final monthRuns = runs.where((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    return monthRuns.length >= 10;
  }

  bool _isLabRat(List<Run> runs) {
    return runs.any((r) => r.deviceInfo?.contains('prototype') == true ||
                        r.distanceM >= 42195);
  }

  Widget _buildTab() {
    final runs = _runs ?? [];
    return switch (_tab) {
      _GamTab.badges => _BadgesTab(
          runs: runs,
          unlockedCount: _countUnlockedBadges(runs),
        ),
      _GamTab.xp     => _XpTab(runs: runs),
      _GamTab.streak => _StreakTab(runs: runs),
    };
  }
}

// ── Nível & XP ───────────────────────────────────────────────────────────────

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

    final rules = [
      ('Completar corrida', '+50–120'),
      ('Atingir pace alvo', '+20'),
      ('Manter streak', '+10/dia'),
      ('Novo badge', '+30'),
      ('Compartilhar card', '+5'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('NÍVEL & XP', style: type.displayMd),
        const SizedBox(height: 16),
        // Level card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border, width: 1.041),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('$level', style: type.dataXl.copyWith(color: palette.primary)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Corredor', style: type.labelMd),
                  Text('$xpInLevel / 500 XP', style: type.bodySm),
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
        // Métricas
        Row(children: [
          Expanded(child: MetricCard(label: 'XP TOTAL', value: '$totalXp')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'CORRIDAS', value: '${runs.length}')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'NÍVEL', value: '$level', accentColor: palette.primary)),
        ]),
        const SizedBox(height: 20),
        // Regras
        ...rules.map((rule) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
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
        )),
      ],
    );
  }
}

// ── Badges ───────────────────────────────────────────────────────────────────

class _BadgesTab extends StatelessWidget {
  final List<Run> runs;
  final int unlockedCount;
  const _BadgesTab({required this.runs, required this.unlockedCount});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;

    int _countStreak(List<Run> runs) {
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

    bool _hasPaceBelow(double targetMinPerKm) {
      for (final r in runs) {
        if (r.distanceM > 0 && r.elapsedSeconds != null) {
          final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
          if (pace < targetMinPerKm) return true;
        }
      }
      return false;
    }

    bool _isTop20Percent() {
      if (runs.length < 5) return false;
      final sorted = List.of(runs)..sort((a, b) {
        final distA = a.distanceM;
        final distB = b.distanceM;
        return distB.compareTo(distA);
      });
      final index20Percent = (sorted.length * 0.2).floor();
      return runs.contains(sorted[index20Percent]);
    }

    bool _isZona(Run r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      return d != null && (d.hour >= 17 && d.hour < 21);
    }

    bool _isNoturno(Run r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      return d != null && (d.hour >= 21 || d.hour < 6);
    }

    bool _isIntervalado(Run r) {
      return (r.distanceM >= 5000 && r.elapsedSeconds != null && r.elapsedSeconds! > 1800) ||
             (r.distanceM >= 10000 && r.elapsedSeconds != null && r.elapsedSeconds! > 3600);
    }

    bool _hasLongRun(double minKm) {
      return runs.any((r) => r.distanceM >= minKm * 1000);
    }

    bool _isSocialRun(Run r) {
      return (r.distanceM >= 5000 && r.elapsedSeconds == null) ||
             (r.distanceM < 5000 && r.distanceM > 0);
    }

    bool _hasFastRecovery() {
      for (final r in runs) {
        if (r.distanceM >= 10000 && r.elapsedSeconds != null) {
          final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
          if (pace < 5.0) return true;
        }
      }
      return false;
    }

    bool _isPerfectMonth() {
      final now = DateTime.now();
      final monthRuns = runs.where((r) {
        final d = DateTime.tryParse(r.createdAt)?.toLocal();
        return d != null && d.year == now.year && d.month == now.month;
      }).toList();
      return monthRuns.length >= 10;
    }

    bool _isLabRat() {
      return runs.any((r) => r.deviceInfo?.contains('prototype') == true ||
                          r.distanceM >= 42195);
    }

    final badges = [
      _BadgeDef(
        title: 'Primeira Corrida',
        description: 'Complete sua primeira corrida',
        icon: Icons.directions_run,
        isUnlocked: runs.isNotEmpty,
        progress: runs.isNotEmpty ? 1.0 : null,
      ),
      _BadgeDef(
        title: '5 Corridas',
        description: 'Complete 5 corridas',
        icon: Icons.star_outline,
        isUnlocked: runs.length >= 5,
        progress: runs.length >= 5 ? 1.0 : (runs.length / 5).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: 'Streak 7',
        description: 'Mantenha streak de 7 dias',
        icon: Icons.hot_tub_outlined,
        isUnlocked: _countStreak(runs) >= 7,
        progress: _countStreak(runs) >= 7 ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Streak 14',
        description: 'Mantenha streak de 14 dias',
        icon: Icons.calendar_today_outlined,
        isUnlocked: _countStreak(runs) >= 14,
        progress: _countStreak(runs) >= 14 ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Pace Sub-6',
        description: 'Corra com pace abaixo de 6min/km',
        icon: Icons.speed_outlined,
        isUnlocked: _hasPaceBelow(6.0),
        progress: _hasPaceBelow(6.0) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Pace Sub-5:30',
        description: 'Corra com pace abaixo de 5:30min/km',
        icon: Icons.timer_outlined,
        isUnlocked: _hasPaceBelow(5.5),
        progress: _hasPaceBelow(5.5) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Top 20%',
        description: 'Entre nos 20% mais rápidos',
        icon: Icons.emoji_events_outlined,
        isUnlocked: _isTop20Percent(),
        progress: _isTop20Percent() ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Zona Master',
        description: 'Corra entre 17h e 21h',
        icon: Icons.location_city_outlined,
        isUnlocked: runs.any(_isZona),
        progress: runs.any(_isZona) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Noturno',
        description: 'Corra após as 21h ou antes das 6h',
        icon: Icons.nightlight_rounded,
        isUnlocked: runs.any(_isNoturno),
        progress: runs.any(_isNoturno) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Intervalado',
        description: 'Corra 5km+ ou 10km+ com bom tempo',
        icon: Icons.bolt_outlined,
        isUnlocked: runs.any(_isIntervalado),
        progress: runs.any(_isIntervalado) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Longão',
        description: 'Corra 21km ou mais',
        icon: Icons.map_outlined,
        isUnlocked: _hasLongRun(21),
        progress: _hasLongRun(21) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Consistente',
        description: 'Corra 10 vezes ou mais',
        icon: Icons.trending_up_outlined,
        isUnlocked: runs.length >= 10,
        progress: runs.length >= 10 ? 1.0 : (runs.length / 10).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: 'Corredor Social',
        description: 'Corra 5km ou mais sem registro de ritmo',
        icon: Icons.groups_outlined,
        isUnlocked: runs.any(_isSocialRun),
        progress: runs.any(_isSocialRun) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Mestre da Recuperação',
        description: 'Corra 10km com pace abaixo de 5min/km',
        icon: Icons.health_and_safety_outlined,
        isUnlocked: _hasFastRecovery(),
        progress: _hasFastRecovery() ? 1.0 : null,
      ),
       _BadgeDef(
         title: 'Escalador',
         description: 'Corra com mais de 100m de ganho de altitude',
         icon: Icons.terrain_outlined,
         isUnlocked: false,
         progress: null,
       ),
      _BadgeDef(
        title: 'Mês Perfeito',
        description: 'Corra 10 vezes este mês',
        icon: Icons.star_rounded,
        isUnlocked: _isPerfectMonth(),
        progress: _isPerfectMonth() ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Veterano',
        description: 'Corra 21 vezes ou mais',
        icon: Icons.military_tech_outlined,
        isUnlocked: runs.length >= 21,
        progress: runs.length >= 21 ? 1.0 : (runs.length / 21).clamp(0.0, 1.0),
      ),
       _BadgeDef(
         title: 'Lab Rat',
          description: 'Corra maratona ou use dispositivo prototype',
          icon: Icons.science_outlined,
          isUnlocked: _isLabRat(),
           progress: _isLabRat() ? 1.0 : null,
       ),
       _BadgeDef(
         title: 'Trail Master',
         description: 'Corra em trilhas ou terrenos irregulares',
         icon: Icons.directions_walk_outlined,
         isUnlocked: false,
         progress: null,
       ),
       _BadgeDef(
         title: 'Indoor Champion',
         description: 'Complete corrida em esteira de 10km+',
         icon: Icons.fitness_center_outlined,
         isUnlocked: false,
         progress: null,
       ),
       _BadgeDef(
         title: 'Maratonista',
         description: 'Corra 42km ou mais',
         icon: Icons.flag_outlined,
         isUnlocked: _hasLongRun(42),
          progress: _hasLongRun(42) ? 1.0 : null,
       ),
       _BadgeDef(
         title: 'Ultra Runner',
         description: 'Corra 50km ou mais',
         icon: Icons.map_outlined,
         isUnlocked: false,
         progress: null,
       ),
     ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('Badges', style: type.displaySm.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        )),
        const SizedBox(height: 6),
        Text(
          '$unlockedCount de 21 desbloqueados',
          style: type.labelMd.copyWith(color: context.runninPalette.muted),
        ),
        const SizedBox(height: 16),
        ...List.generate((badges.length / 2).ceil(), (row) {
          final a = badges[row * 2];
          final b = row * 2 + 1 < badges.length ? badges[row * 2 + 1] : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AchievementCard(
                  title: a.title, description: a.description,
                  icon: a.icon, isUnlocked: a.isUnlocked, progress: a.progress ?? 0.0,
                )),
                const SizedBox(width: 6),
                Expanded(child: b == null
                    ? const SizedBox.shrink()
                    : AchievementCard(
                        title: b.title, description: b.description,
                        icon: b.icon, isUnlocked: b.isUnlocked, progress: b.progress ?? 0.0,
                      )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _BadgeDef {
  final String title, description;
  final IconData icon;
  final bool isUnlocked;
  final double? progress;
  const _BadgeDef({
    required this.title, required this.description,
    required this.icon, required this.isUnlocked, this.progress,
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

    // Streak atual
    int streak = 0;
    DateTime day = DateTime.now();
    while (runDays.contains(DateTime(day.year, day.month, day.day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    // Recorde de streak
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

    // Calendário do mês atual
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('STREAK', style: type.displayMd),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: MetricCard(
            label: 'STREAK ATUAL', value: '$streak', unit: 'dias',
            accentColor: streak > 0 ? palette.primary : Colors.transparent,
          )),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'RECORDE', value: '$best', unit: 'dias')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'DIAS TREINADOS', value: '${runDays.length}')),
        ]),
        const SizedBox(height: 20),
        // Cabeçalho do calendário
        Text(
          '${_monthName(now.month)} ${now.year}'.toUpperCase(),
          style: type.labelCaps,
        ),
        const SizedBox(height: 8),
        // Dias da semana
        Row(children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'].map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center, style: type.labelCaps),
        )).toList()),
        const SizedBox(height: 8),
        // Grid do calendário
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
                      width: 1.041,
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
