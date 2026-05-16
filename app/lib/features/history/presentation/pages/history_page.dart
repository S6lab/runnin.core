import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/history/presentation/widgets/hist_stat_card.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/chart_panel.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _Period { week, month, threeMonths }

enum _ContentTab { data, runs, bench }

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
  bool _benchmarkLoading = false;
  double? _benchmarkPercentile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await _remote.listRuns(limit: 200);
      if (mounted) {
        setState(() { 
          _allRuns = runs; 
          _loading = false; 
          if (runs.isNotEmpty) {
            _benchmarkPercentile = HistStatCard.computeBenchmarkPercentile(runs);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corridas.'; _loading = false; });
    }
  }

  Future<void> _loadBenchmark() async {
    setState(() { _benchmarkLoading = true; });
    try {
      if (_allRuns != null && _allRuns!.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() { 
            _benchmarkPercentile = HistStatCard.computeBenchmarkPercentile(_allRuns!);
            _benchmarkLoading = false; 
          });
        }
      } else {
        setState(() { _benchmarkLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _benchmarkLoading = false; });
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
                tabs: const ['DADOS', 'CORRIDAS', 'BENCH'],
                selectedIndex: _ContentTab.values.indexOf(_tab),
                onChanged: (i) {
                  final newTab = _ContentTab.values[i];
                  setState(() => _tab = newTab);
                  if (newTab == _ContentTab.bench && _benchmarkPercentile == null) {
                    _loadBenchmark();
                  }
                },
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

    final benchmarkWidget = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          if (_benchmarkLoading || _benchmarkPercentile == null)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'BENCHMARK',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  FigmaBenchmarkBellCurve(userPercentile: _benchmarkPercentile!),
                  const SizedBox(height: 8),
                  Text(
                    'Você está no ${_benchmarkPercentile!.toInt()}º percentil '
                    'em relação à média dos usuários.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: _load,
      child: _tab == _ContentTab.data
          ? _DataView(runs: runs)
          : _tab == _ContentTab.runs
              ? _RunsListView(runs: runs)
              : benchmarkWidget,
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
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'CORRIDAS',
            value: '${stats.count}',
            valueColor: FigmaColors.brandCyan,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'VOLUME',
            value: stats.totalKm.toStringAsFixed(1),
            unit: 'km',
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'TEMPO',
            value: stats.totalTimeLabel,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'PACE MÉD.',
            value: stats.avgPaceLabel,
            unit: '/km',
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'STREAK',
            value: '${stats.streakDays}',
            unit: 'd',
            valueColor: stats.streakDays > 2
                ? FigmaColors.brandOrange
                : FigmaColors.textPrimary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'XP',
            value: '${stats.totalXp}',
            valueColor: FigmaColors.brandCyan,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'BPM MÉD.',
            value: stats.avgBpm?.toString() ?? '--',
            unit: 'BPM',
          )),
        ]),
        const SizedBox(height: 16),

        // Seção Zonas Cardíacas
        if (stats.zoneDistribution.isNotEmpty)
          ChartPanel(
            title: 'ZONAS CARDÍACAS',
            subtitle: 'Distribuição de tempo nas zonas',
            child: FigmaZoneDistributionBar(
              zonePercentages: stats.zoneDistribution,
            ),
          ),
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

        // Evolução Resumo
        Row(children: [
          Expanded(child: FigmaStatTileWithDelta(
            label: 'PACE',
            value: stats.avgPaceLabel,
            delta: '+5s',
            deltaIsPositive: false,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaStatTileWithDelta(
            label: 'VOLUME',
            value: stats.totalKm.toStringAsFixed(1),
            unit: 'km',
            delta: '+2.5km',
            deltaIsPositive: true,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaStatTileWithDelta(
            label: 'BPM',
            value: stats.avgBpm?.toString() ?? '--',
            unit: 'BPM',
            delta: '-2',
            deltaIsPositive: true,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaStatTileWithDelta(
            label: 'CORRIDAS',
            value: '${stats.count}',
            delta: '+1',
            deltaIsPositive: true,
          )),
        ]),
        const SizedBox(height: 16),

        // Coach.AI Análise
        FigmaCoachAIBlock(
          child: Text(
            _buildCoachNarrative(stats),
            style: context.runninType.bodyMd.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  _HistoryStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _HistoryStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    final runningCount = runs.where((r) => r.status == 'completed').length;

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

    // BPM médio
    int? avgBpm;
    final runsWithAvg = runs.where((r) => r.avgPace != null).toList();
    if (runsWithAvg.isNotEmpty) {
      final totalBpm = runsWithAvg.fold<int>(0, (s, r) => s + (r.avgBpm ?? 0));
      avgBpm = totalBpm ~/ runsWithAvg.length;
    }

    // Zonas cardíacas (simulado se não tiver dados)
    final runsWithBpm = runs.where((r) => r.avgBpm != null && r.avgBpm! > 0).toList();
    List<double> zoneDistribution = [];
    if (runsWithBpm.isNotEmpty) {
      int z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0;
      for (final r in runsWithBpm) {
        final bpm = r.avgBpm!;
        if (bpm < 100) z1++;
        else if (bpm < 120) z2++;
        else if (bpm < 145) z3++;
        else if (bpm < 170) z4++;
        else z5++;
      }
      final total = runsWithBpm.length;
      zoneDistribution = [
        (z1 / total) * 100,
        (z2 / total) * 100,
        (z3 / total) * 100,
        (z4 / total) * 100,
        (z5 / total) * 100,
      ];
    }

    // Volume por semana (últimas 4 semanas)
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
      runningCount: runningCount,
      totalKm: totalDistM / 1000,
      totalTimeLabel: totalTimeLabel,
      avgPaceLabel: avgPaceLabel,
      streakDays: streak,
      totalXp: totalXp,
      avgBpm: avgBpm,
      zoneDistribution: zoneDistribution,
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

  String _computeEficiencia(double totalKm, int totalS, int runningCount) {
    if (runningCount == 0 || totalS == 0) return '--';
    final hours = totalS / 3600;
    final kmh = totalKm / hours;
    return '${kmh.toStringAsFixed(1)}';
  }
}

class _HistoryStats {
  final int count;
  final int runningCount;
  final double totalKm;
  final int totalS;
  final String totalTimeLabel;
  final String avgPaceLabel;
  final int streakDays;
  final int totalXp;
  final int? avgBpm;
  final List<double> zoneDistribution;
  final List<_WeeklyEntry> weeklyVolume;

  const _HistoryStats({
    required this.count,
    this.runningCount = 0,
    required this.totalKm,
    required this.totalS,
    required this.totalTimeLabel,
    required this.avgPaceLabel,
    required this.streakDays,
    required this.totalXp,
    this.avgBpm,
    this.zoneDistribution = const [],
    required this.weeklyVolume,
  });

  factory _HistoryStats.empty() => const _HistoryStats(
    count: 0, runningCount: 0, totalKm: 0, totalS: 0, totalTimeLabel: '0m',
    avgPaceLabel: '--:--', streakDays: 0, totalXp: 0,
    avgBpm: null, zoneDistribution: [], weeklyVolume: [],
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
      itemBuilder: (_, i) => FigmaRunCard(
        typeLabel: runs[i].type.toUpperCase(),
        dateLabel: _fmtDate(runs[i].createdAt),
        distanceKm: runs[i].distanceM / 1000,
        pace: runs[i].avgPace ?? '--:--',
        duration: _fmtDuration(runs[i].durationS),
        coachPreview: runs[i].type,
        onTap: () => context.push('/report', extra: runs[i].id),
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
