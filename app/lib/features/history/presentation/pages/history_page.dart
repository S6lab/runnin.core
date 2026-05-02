import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/chart_panel.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _Period { week, month, threeMonths }

enum _ContentTab { data, runs }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _allRuns;
  bool _loading = true;
  String? _error;
  _Period _period = _Period.month;
  _ContentTab _tab = _ContentTab.data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await _remote.listRuns(limit: 90);
      if (mounted) setState(() { _allRuns = runs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corridas.'; _loading = false; });
    }
  }

  List<Run> get _filteredRuns {
    if (_allRuns == null) return [];
    final cutoff = switch (_period) {
      _Period.week       => DateTime.now().subtract(const Duration(days: 7)),
      _Period.month      => DateTime.now().subtract(const Duration(days: 30)),
      _Period.threeMonths => DateTime.now().subtract(const Duration(days: 90)),
    };
    return _allRuns!
        .where((r) {
          final d = DateTime.tryParse(r.createdAt);
          return d != null && d.isAfter(cutoff);
        })
        .where((r) => r.status == 'completed')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'HISTÓRICO'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['SEMANA', 'MÊS', '3 MESES'],
                selectedIndex: _Period.values.indexOf(_period),
                onChanged: (i) => setState(() => _period = _Period.values[i]),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['DADOS', 'CORRIDAS'],
                selectedIndex: _ContentTab.values.indexOf(_tab),
                onChanged: (i) => setState(() => _tab = _ContentTab.values[i]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final palette = context.runninPalette;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: TextStyle(color: palette.muted)),
        const SizedBox(height: 16),
        TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
      ]));
    }

    final runs = _filteredRuns;

    if (runs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_run_outlined, size: 40, color: palette.border),
        const SizedBox(height: 12),
        Text('Nenhuma corrida no período.', style: TextStyle(color: palette.muted)),
      ]));
    }

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: _load,
      child: _tab == _ContentTab.data
          ? _DataView(runs: runs)
          : _RunsListView(runs: runs),
    );
  }
}

// ── Aba Dados ───────────────────────────────────────────────────────────────

class _DataView extends StatelessWidget {
  final List<Run> runs;
  const _DataView({required this.runs});

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Totais
        Row(children: [
          Expanded(child: MetricCard(label: 'CORRIDAS', value: '${stats.count}')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(
            label: 'VOLUME',
            value: stats.totalKm.toStringAsFixed(1),
            unit: 'km',
          )),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'TEMPO', value: stats.totalTimeLabel)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: MetricCard(
            label: 'PACE MÉD.',
            value: stats.avgPaceLabel,
            unit: '/km',
          )),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(
            label: 'STREAK',
            value: '${stats.streakDays}',
            unit: 'd',
          )),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'XP', value: '${stats.totalXp}')),
        ]),
        const SizedBox(height: 16),

        // Volume semanal
        if (stats.weeklyVolume.isNotEmpty)
          ChartPanel(
            title: 'VOLUME SEMANAL',
            subtitle: 'Km total por semana — carga de treino progressiva',
            child: SimpleBarChart(
              values: stats.weeklyVolume.map((e) => e.km).toList(),
              labels: stats.weeklyVolume.map((e) => e.label).toList(),
            ),
          ),
        const SizedBox(height: 16),

        // Análise do Coach
        CoachNarrativeCard(
          text: _buildCoachNarrative(stats),
          borderColor: context.runninPalette.secondary,
        ),
      ],
    );
  }

  _HistoryStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _HistoryStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));

    // Pace médio em segundos/km
    int? avgPaceSec;
    final runsWithPace = runs.where((r) => r.avgPace != null).toList();
    if (runsWithPace.isNotEmpty) {
      final paceSecsTotal = runsWithPace.fold<int>(0, (s, r) {
        final parts = r.avgPace!.split(':');
        if (parts.length != 2) return s;
        final m = int.tryParse(parts[0]) ?? 0;
        final sec = int.tryParse(parts[1]) ?? 0;
        return s + m * 60 + sec;
      });
      avgPaceSec = paceSecsTotal ~/ runsWithPace.length;
    }

    final avgPaceLabel = avgPaceSec == null
        ? '--:--'
        : '${avgPaceSec ~/ 60}:${(avgPaceSec % 60).toString().padLeft(2, '0')}';

    // Volume por semana
    final Map<String, double> weekMap = {};
    for (final r in runs) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) continue;
      final monday = d.subtract(Duration(days: d.weekday - 1));
      final key = '${monday.day}/${monday.month}';
      weekMap[key] = (weekMap[key] ?? 0) + r.distanceM / 1000;
    }
    final weeklyVolume = weekMap.entries
        .map((e) => _WeeklyEntry(label: e.key, km: e.value))
        .toList();

    // Streak simples: dias consecutivos com corrida
    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet().toList()..sort();

    int streak = 0;
    DateTime? prev;
    for (final day in runDays.reversed) {
      if (prev == null || prev.difference(day).inDays == 1) {
        streak++;
        prev = day;
      } else { break; }
    }

    final totalMin = totalS ~/ 60;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    final totalTimeLabel = h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';

    return _HistoryStats(
      count: runs.length,
      totalKm: totalDistM / 1000,
      totalTimeLabel: totalTimeLabel,
      avgPaceLabel: avgPaceLabel,
      streakDays: streak,
      totalXp: totalXp,
      weeklyVolume: weeklyVolume,
    );
  }

  String _buildCoachNarrative(_HistoryStats s) {
    if (s.count == 0) return 'Sem corridas no período para análise.';
    return 'Você completou ${s.count} corridas com ${s.totalKm.toStringAsFixed(1)} km '
        'e pace médio de ${s.avgPaceLabel}/km. '
        '${s.streakDays > 2 ? "Excelente consistência de ${s.streakDays} dias! " : ""}'
        'Continue mantendo a progressão de volume semanal para evoluir no ciclo.';
  }
}

class _HistoryStats {
  final int count;
  final double totalKm;
  final String totalTimeLabel;
  final String avgPaceLabel;
  final int streakDays;
  final int totalXp;
  final List<_WeeklyEntry> weeklyVolume;

  const _HistoryStats({
    required this.count,
    required this.totalKm,
    required this.totalTimeLabel,
    required this.avgPaceLabel,
    required this.streakDays,
    required this.totalXp,
    required this.weeklyVolume,
  });

  factory _HistoryStats.empty() => const _HistoryStats(
    count: 0, totalKm: 0, totalTimeLabel: '0m',
    avgPaceLabel: '--:--', streakDays: 0, totalXp: 0, weeklyVolume: [],
  );
}

class _WeeklyEntry {
  final String label;
  final double km;
  const _WeeklyEntry({required this.label, required this.km});
}

// ── Aba Corridas ─────────────────────────────────────────────────────────────

class _RunsListView extends StatelessWidget {
  final List<Run> runs;
  const _RunsListView({required this.runs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: runs.length,
      itemBuilder: (_, i) => _RunCard(run: runs[i]),
    );
  }
}

class _RunCard extends StatelessWidget {
  final Run run;
  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final km = (run.distanceM / 1000).toStringAsFixed(2);
    final date = _fmtDate(run.createdAt);
    final duration = _fmtDuration(run.durationS);

    return GestureDetector(
      onTap: () => context.push('/report', extra: run.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            // Data
            SizedBox(
              width: 36,
              child: Text(
                date.replaceAll(' ', '\n'),
                textAlign: TextAlign.center,
                style: type.labelCaps.copyWith(height: 1.3),
              ),
            ),
            const SizedBox(width: 12),
            // Tipo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: palette.primary.withValues(alpha: 0.15),
              child: Text(
                run.type.toUpperCase(),
                style: type.labelCaps.copyWith(color: palette.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Métricas
            Expanded(
              child: Row(
                children: [
                  _Stat(value: km, unit: 'km'),
                  const SizedBox(width: 16),
                  _Stat(value: duration, unit: ''),
                  if (run.avgPace != null) ...[
                    const SizedBox(width: 16),
                    _Stat(value: run.avgPace!, unit: '/km'),
                  ],
                ],
              ),
            ),
            if (run.xpEarned != null && run.xpEarned! > 0) ...[
              const SizedBox(width: 8),
              Text(
                '+${run.xpEarned}xp',
                style: type.labelCaps.copyWith(color: palette.primary),
              ),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: palette.muted),
          ],
        ),
      ),
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

class _Stat extends StatelessWidget {
  final String value;
  final String unit;
  const _Stat({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return RichText(
      text: TextSpan(
        text: value,
        style: type.dataSm,
        children: [
          if (unit.isNotEmpty)
            TextSpan(text: unit, style: type.bodySm),
        ],
      ),
    );
  }
}
