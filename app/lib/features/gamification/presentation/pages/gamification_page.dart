import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
import 'package:runnin/shared/widgets/gamification/export.dart';
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
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTab(),
            ),
          ],
        ),
      ),
    );
  }

              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTab(),
}

// ── Badges tab ───────────────────────────────────────────────────────────────

class _BadgesTab extends StatelessWidget {
  final List<Run> runs;
  const _BadgesTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    final unlockedCount = countUnlockedBadges(runs);

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
        isUnlocked: hasPaceBelow(runs, 6.0),
        progress: hasPaceBelow(runs, 6.0) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Pace Sub-5:30',
        description: 'Corra com pace abaixo de 5:30min/km',
        icon: Icons.timer_outlined,
        isUnlocked: hasPaceBelow(runs, 5.5),
        progress: hasPaceBelow(runs, 5.5) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Top 20%',
        description: 'Entre nos 20% mais rápidos',
        icon: Icons.emoji_events_outlined,
        isUnlocked: isTop20Percent(runs),
        progress: isTop20Percent(runs) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Zona Master',
        description: 'Corra entre 17h e 21h',
        icon: Icons.location_city_outlined,
        isUnlocked: runs.any(isZona),
        progress: runs.any(isZona) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Noturno',
        description: 'Corra após as 21h ou antes das 6h',
        icon: Icons.nightlight_rounded,
        isUnlocked: runs.any(isNoturno),
        progress: runs.any(isNoturno) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Intervalado',
        description: 'Corra 5km+ ou 10km+ com bom tempo',
        icon: Icons.bolt_outlined,
        isUnlocked: runs.any(isIntervalado),
        progress: runs.any(isIntervalado) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Longão',
        description: 'Corra 21km ou mais',
        icon: Icons.map_outlined,
        isUnlocked: hasLongRun(runs, 21),
        progress: hasLongRun(runs, 21) ? 1.0 : null,
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
        isUnlocked: runs.any(isSocialRun),
        progress: runs.any(isSocialRun) ? 1.0 : null,
      ),
      _BadgeDef(
        title: 'Mestre da Recuperação',
        description: 'Corra 10km com pace abaixo de 5min/km',
        icon: Icons.health_and_safety_outlined,
        isUnlocked: hasFastRecovery(runs),
        progress: hasFastRecovery(runs) ? 1.0 : null,
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
        isUnlocked: isPerfectMonth(runs),
        progress: isPerfectMonth(runs) ? 1.0 : null,
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
        isUnlocked: isLabRat(runs),
        progress: isLabRat(runs) ? 1.0 : null,
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
        isUnlocked: hasLongRun(runs, 42),
        progress: hasLongRun(runs, 42) ? 1.0 : null,
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
                Expanded(child: FigmaBadgeCard(
                  title: a.title, description: a.description,
                  icon: a.icon, unlocked: a.isUnlocked, progress: a.progress ?? 0.0,
                )),
                const SizedBox(width: 6),
                Expanded(child: b == null
                    ? const SizedBox.shrink()
                    : FigmaBadgeCard(
                        title: b.title, description: b.description,
                        icon: b.icon, unlocked: b.isUnlocked, progress: b.progress ?? 0.0,
                      )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── XP tab ───────────────────────────────────────────────────────────────────

class _XpTab extends StatelessWidget {
  final List<Run> runs;
  const _XpTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    final level = (totalXp / 500).floor() + 1;
    final xpInLevel = totalXp - (level - 1) * 500;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        FigmaXpLevelCard(
          level: level,
          levelLabel: 'Corredor',
          currentXp: xpInLevel,
          nextLevelXp: 500,
        ),
      ],
    );
  }
}

// ── Streak tab ───────────────────────────────────────────────────────────────

class _StreakTab extends StatelessWidget {
  final List<Run> runs;
  const _StreakTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;

    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt)?.toLocal();
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet();

    final streak = _countStreak(runs);
    final best = _countBestStreak(runDays);
    final activeDays = _buildActiveDays(runDays);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('STREAK', style: type.displaySm),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'ATUAL',
            value: '$streak',
            unit: 'd',
            valueColor: streak > 0 ? FigmaColors.brandCyan : FigmaColors.textPrimary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(label: 'RECORDE', value: '$best', unit: 'd')),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(label: 'DIAS', value: '${runDays.length}')),
        ]),
        const SizedBox(height: 20),
        FigmaStreakCalendarGrid(activeDays: activeDays),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

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

int _countBestStreak(Set<DateTime> runDays) {
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

// Maps the last 28 days to 0-indexed grid positions for FigmaStreakCalendarGrid.
// Index 0 = 27 days ago, index 27 = today.
List<int> _buildActiveDays(Set<DateTime> runDays) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final active = <int>[];
  for (int i = 0; i < 28; i++) {
    final day = today.subtract(Duration(days: 27 - i));
    if (runDays.contains(day)) active.add(i);
  }
  return active;
}

int countUnlockedBadges(List<Run> runs) {
  final unlocked = <bool>[];

  unlocked.add(runs.isNotEmpty);
  unlocked.add(runs.length >= 5);
  unlocked.add(_countStreak(runs) >= 7);
  unlocked.add(_countStreak(runs) >= 14);
  unlocked.add(hasPaceBelow(runs, 6.0));
  unlocked.add(hasPaceBelow(runs, 5.5));
  unlocked.add(isTop20Percent(runs));
  unlocked.add(runs.any(isZona));
  unlocked.add(runs.any(isNoturno));
  unlocked.add(runs.any(isIntervalado));
  unlocked.add(hasLongRun(runs, 21));
  unlocked.add(runs.length >= 10);
  unlocked.add(runs.any(isSocialRun));
  unlocked.add(hasFastRecovery(runs));
  unlocked.add(runs.any(hasHillRun));
  unlocked.add(isPerfectMonth(runs));
  unlocked.add(runs.length >= 21);
  unlocked.add(isLabRat(runs));

  return unlocked.where((b) => b).length;
}

bool hasPaceBelow(List<Run> runs, double targetMinPerKm) {
  for (final r in runs) {
    if (r.distanceM > 0 && r.elapsedSeconds != null) {
      final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
      if (pace < targetMinPerKm) return true;
    }
  }
  return false;
}

bool isTop20Percent(List<Run> runs) {
  if (runs.length < 5) return false;
  final sorted = List.of(runs)..sort((a, b) {
    final distA = a.distanceM;
    final distB = b.distanceM;
    return distB.compareTo(distA);
  });
  final index20Percent = (sorted.length * 0.2).floor();
  return runs.contains(sorted[index20Percent]);
}

bool isZona(Run r) {
  final d = DateTime.tryParse(r.createdAt)?.toLocal();
  return d != null && (d.hour >= 17 && d.hour < 21);
}

bool isNoturno(Run r) {
  final d = DateTime.tryParse(r.createdAt)?.toLocal();
  return d != null && (d.hour >= 21 || d.hour < 6);
}

bool isIntervalado(Run r) {
  return (r.distanceM >= 5000 && r.elapsedSeconds != null && r.elapsedSeconds! > 1800) ||
         (r.distanceM >= 10000 && r.elapsedSeconds != null && r.elapsedSeconds! > 3600);
}

bool hasLongRun(List<Run> runs, double minKm) {
  return runs.any((r) => r.distanceM >= minKm * 1000);
}

bool isSocialRun(Run r) {
  return (r.distanceM >= 5000 && r.elapsedSeconds == null) ||
         (r.distanceM < 5000 && r.distanceM > 0);
}

bool hasFastRecovery(List<Run> runs) {
  for (final r in runs) {
    if (r.distanceM >= 10000 && r.elapsedSeconds != null) {
      final pace = (r.elapsedSeconds! / 60) / (r.distanceM / 1000);
      if (pace < 5.0) return true;
    }
  }
  return false;
}

bool hasHillRun(Run r) {
  return r.elevationGain != null && r.elevationGain! > 100;
}

bool isPerfectMonth(List<Run> runs) {
  final now = DateTime.now();
  final monthRuns = runs.where((r) {
    final d = DateTime.tryParse(r.createdAt)?.toLocal();
    return d != null && d.year == now.year && d.month == now.month;
  }).toList();
  return monthRuns.length >= 10;
}

bool isLabRat(List<Run> runs) {
  return runs.any((r) => r.deviceInfo?.contains('prototype') == true ||
                      r.distanceM >= 42195);
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
