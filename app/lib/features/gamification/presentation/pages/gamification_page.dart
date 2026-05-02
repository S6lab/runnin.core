import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/achievement_card.dart';
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
            // Header
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
            border: Border.all(color: palette.border),
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
  const _BadgesTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    final totalKm = runs.fold<double>(0.0, (s, r) => s + r.distanceM) / 1000;

    final badges = [
      _BadgeDef(
        title: 'Primeira Corrida',
        description: 'Complete sua primeira corrida',
        icon: Icons.directions_run,
        isUnlocked: runs.isNotEmpty,
        progress: runs.isNotEmpty ? 1.0 : 0.0,
      ),
      _BadgeDef(
        title: '5 Corridas',
        description: 'Complete 5 corridas',
        icon: Icons.star_outline,
        isUnlocked: runs.length >= 5,
        progress: (runs.length / 5).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: '10 Corridas',
        description: 'Complete 10 corridas',
        icon: Icons.military_tech_outlined,
        isUnlocked: runs.length >= 10,
        progress: (runs.length / 10).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: '50 km',
        description: 'Acumule 50 km rodados',
        icon: Icons.route_outlined,
        isUnlocked: totalKm >= 50,
        progress: (totalKm / 50).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: '100 km',
        description: 'Acumule 100 km rodados',
        icon: Icons.emoji_events_outlined,
        isUnlocked: totalKm >= 100,
        progress: (totalKm / 100).clamp(0.0, 1.0),
      ),
      _BadgeDef(
        title: 'Madrugador',
        description: 'Corra antes das 7h',
        icon: Icons.wb_twilight,
        isUnlocked: runs.any(_isEarlyMorning),
        progress: runs.any(_isEarlyMorning) ? 1.0 : 0.0,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('BADGES', style: type.displayMd),
        const SizedBox(height: 16),
        ...List.generate((badges.length / 2).ceil(), (row) {
          final a = badges[row * 2];
          final b = row * 2 + 1 < badges.length ? badges[row * 2 + 1] : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AchievementCard(
                  title: a.title, description: a.description,
                  icon: a.icon, isUnlocked: a.isUnlocked, progress: a.progress,
                )),
                const SizedBox(width: 8),
                Expanded(child: b == null
                    ? const SizedBox.shrink()
                    : AchievementCard(
                        title: b.title, description: b.description,
                        icon: b.icon, isUnlocked: b.isUnlocked, progress: b.progress,
                      )),
              ],
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
}

class _BadgeDef {
  final String title, description;
  final IconData icon;
  final bool isUnlocked;
  final double progress;
  const _BadgeDef({
    required this.title, required this.description,
    required this.icon, required this.isUnlocked, required this.progress,
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
            accentColor: streak > 0 ? palette.primary : null,
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
