import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/history/data/benchmark_remote_datasource.dart' show BenchmarkRemoteDatasource;
import 'package:runnin/features/history/data/period_analysis_remote_datasource.dart';
import 'package:runnin/features/history/data/stats_remote_datasource.dart';
import 'package:runnin/features/history/domain/entities/period_analysis.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/chart_panel.dart';
import 'package:runnin/shared/widgets/two_tone_bar_chart.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
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
  final _planRemote = PlanRemoteDatasource();
  List<Run>? _allRuns;
  Plan? _plan;
  bool _loading = true;
  String? _error;
  _Period _period = _Period.month;
  _ContentTab _tab = _ContentTab.data;
  bool _benchmarkLoading = false;
  double? _benchmarkPercentile;
  List<BenchmarkRow> _benchmarkTableData = [];
  int _benchmarkCohortSize = 0;
  bool _benchmarkEmpty = false;
  final _benchmarkDatasource = BenchmarkRemoteDatasource();
  final _periodAnalysisDatasource = PeriodAnalysisRemoteDatasource();
  PeriodAnalysis? _periodAnalysis;
  bool _loadingAnalysis = false;
  final _statsDatasource = StatsRemoteDatasource();
  StatsAggregate? _aggregate;

  int get _analysisLimit => switch (_period) {
    _Period.week => 10,
    _Period.month => 30,
    _Period.threeMonths => 90,
  };

  String get _periodKey => switch (_period) {
    _Period.week => 'week',
    _Period.month => 'month',
    _Period.threeMonths => 'threeMonths',
  };

  @override
  void initState() {
    super.initState();
    _load();
    _loadPeriodAnalysis();
    _loadAggregate();
  }

  Future<void> _loadAggregate() async {
    if (!mounted) return;
    try {
      final result = await _statsDatasource.getAggregate(_periodKey);
      if (mounted) setState(() => _aggregate = result);
    } catch (_) {
      // Sem aggregate, fallback nos deltas hardcoded.
    }
  }

  Future<void> _loadPeriodAnalysis() async {
    if (!mounted) return;
    setState(() => _loadingAnalysis = true);
    try {
      final result = await _periodAnalysisDatasource.getPeriodAnalysis(_analysisLimit);
      if (mounted) setState(() { _periodAnalysis = result; _loadingAnalysis = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAnalysis = false);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Carrega runs e plano em paralelo. Plano pode falhar (freemium /
      // user sem plano) — não bloqueia listagem de runs.
      final results = await Future.wait<dynamic>([
        _remote.listRuns(limit: 200),
        _planRemote.getCurrentPlan().catchError((_) => null),
      ]);
      final runs = results[0] as List<Run>;
      final plan = results[1] as Plan?;
      if (mounted) {
        setState(() {
          _allRuns = runs;
          _plan = plan;
          _loading = false;
        });
        if (runs.isNotEmpty) {
          _loadBenchmarkTable(runs.first.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corridas.'; _loading = false; });
    }
  }

  Future<void> _loadBenchmark() async {
    if (_allRuns == null || _allRuns!.isEmpty) return;
    _loadBenchmarkTable(_allRuns!.first.id);
  }

  Future<void> _loadBenchmarkTable(String runId) async {
    setState(() { });
    try {
      final result = await _benchmarkDatasource.getBenchmark(runId);
      if (mounted) {
        setState(() { 
          _benchmarkTableData = result.items;
          _benchmarkPercentile = result.percentileTop.toDouble();
          _benchmarkCohortSize = result.cohortSize;
          _benchmarkEmpty = result.cohortSize == 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() { });
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
            const FigmaTopNav(breadcrumb: 'HISTÓRICO'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SegmentedTabBar(
                tabs: const ['SEMANA', 'MÊS', '3 MESES'],
                selectedIndex: _Period.values.indexOf(_period),
                onChanged: (i) {
                  setState(() => _period = _Period.values[i]);
                  _loadPeriodAnalysis();
                  _loadAggregate();
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SegmentedTabBar(
                tabs: const ['DADOS', 'CORRIDAS', 'BENCH'],
                selectedIndex: _ContentTab.values.indexOf(_tab),
                onChanged: (i) {
                  final newTab = _ContentTab.values[i];
                  setState(() => _tab = newTab);
                  if (newTab == _ContentTab.bench) {
                    _loadBenchmark();
                    if (_allRuns != null && _allRuns!.isNotEmpty) {
                      final lastRunId = _allRuns!.first.id;
                      _loadBenchmarkTable(lastRunId);
                    }
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
        Text(_error!, style: context.runninType.bodySm.copyWith(color: palette.muted)),
        const SizedBox(height: 16),
        TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
      ]));
    }

    final runs = _filteredRuns;

    if (runs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_run_outlined, size: 40, color: palette.border),
        const SizedBox(height: 12),
        Text('Nenhuma corrida no período.', style: context.runninType.bodySm.copyWith(color: palette.muted)),
      ]));
    }

    final benchmarkWidget = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          if (_benchmarkEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
              ),
              child: Center(
                    child: Text(
                      'Sem dados suficientes na sua cohort ainda',
                      style: context.runninType.bodySm.copyWith(color: palette.muted),
                    ),
                  )
            )
          else if (_benchmarkLoading || _benchmarkPercentile == null)
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
                  Text(
                    'BENCHMARK',
                    style: context.runninType.bodyMd.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FigmaBenchmarkBellCurve(userPercentile: _benchmarkPercentile!),
                  const SizedBox(height: 8),
                  Text(
                    'Você está no ${_benchmarkPercentile!.toInt()}º percentil '
                    'em relação à média dos usuários.',
                    textAlign: TextAlign.center,
                    style: context.runninType.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_benchmarkTableData.isNotEmpty)
              FigmaBenchmarkTable(benchmarkData: _benchmarkTableData)
            else if (_benchmarkLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.border),
                ),
                child: Center(
                  child: Text(
                    'Carregando dados de benchmark...',
                    style: context.runninType.bodySm.copyWith(color: palette.muted),
                  ),
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
          ? _DataView(runs: runs, plan: _plan, period: _period, periodAnalysis: _periodAnalysis, loadingAnalysis: _loadingAnalysis, aggregate: _aggregate)
          : _tab == _ContentTab.runs
              ? _RunsListView(runs: runs)
              : benchmarkWidget,
    );
  }
}

// ── Aba Dados ───────────────────────────────────────────────────────────────

class _DataView extends StatelessWidget {
  final List<Run> runs;
  final Plan? plan;
  final _Period period;
  final PeriodAnalysis? periodAnalysis;
  final bool loadingAnalysis;
  final StatsAggregate? aggregate;
  const _DataView({required this.runs, required this.plan, required this.period, this.periodAnalysis, this.loadingAnalysis = false, this.aggregate});

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Ciclo de cores [primary, secondary, white] alternados nos cards
        // pra criar ritmo visual sem ter que escolher caso a caso.
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'CORRIDAS',
            value: '${stats.count}',
            valueColor: context.runninPalette.primary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'VOLUME',
            value: stats.totalKm.toStringAsFixed(1),
            unit: 'km',
            valueColor: context.runninPalette.secondary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'TEMPO',
            value: stats.totalTimeLabel,
            valueColor: FigmaColors.textPrimary,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'PACE',
            value: stats.avgPaceLabel,
            unit: '/km',
            valueColor: context.runninPalette.primary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'STREAK',
            value: '${stats.streakDays}',
            unit: 'd',
            valueColor: context.runninPalette.secondary,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaHistStatCard(
            label: 'XP',
            value: '${stats.totalXp}',
            valueColor: FigmaColors.textPrimary,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaHistStatCard(
            label: 'BPM MÉD.',
            value: stats.avgBpm?.toString() ?? '--',
            unit: 'BPM',
            valueColor: context.runninPalette.primary,
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

        // Volume dinâmico: agrupa por dia/semana/mês baseado no period
        // selecionado. Two-tone planned (palette.primary) vs executed
        // (palette.secondary). Quando user não tem plano, mostra só
        // executed (planned=0 em todos buckets).
        ChartPanel(
          title: _volumeTitle(period),
          subtitle: _volumeSubtitle(period),
          height: 200,
          child: TwoToneBarChart(
            data: _buildVolumeBuckets(period, plan, runs),
          ),
        ),
        const SizedBox(height: 16),

        // Evolução Resumo — deltas vêm de /stats/aggregate quando disponível,
        // fallback pra '--' enquanto carrega ou se backend não responde.
        Row(children: [
          Expanded(child: FigmaStatTileWithDelta(
            label: 'PACE',
            value: stats.avgPaceLabel,
            delta: _fmtDeltaPct(aggregate?.deltas.pacePctVsPrev),
            // pace: lower = better → delta negativo é "positivo" pro usuário
            deltaIsPositive: (aggregate?.deltas.pacePctVsPrev ?? 0) <= 0,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaStatTileWithDelta(
            label: 'VOLUME',
            value: stats.totalKm.toStringAsFixed(1),
            unit: 'km',
            delta: _fmtDeltaPct(aggregate?.deltas.volumePctVsPrev),
            deltaIsPositive: (aggregate?.deltas.volumePctVsPrev ?? 0) >= 0,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FigmaStatTileWithDelta(
            label: 'BPM',
            value: stats.avgBpm?.toString() ?? '--',
            unit: 'BPM',
            delta: _fmtDeltaBpm(aggregate?.deltas.bpmDeltaBpm),
            // bpm: lower = better → delta negativo é "positivo"
            deltaIsPositive: (aggregate?.deltas.bpmDeltaBpm ?? 0) <= 0,
          )),
          const SizedBox(width: 8),
          Expanded(child: FigmaStatTileWithDelta(
            label: 'CORRIDAS',
            value: '${stats.count}',
            delta: _fmtDeltaInt(aggregate?.deltas.runsCountDelta),
            deltaIsPositive: (aggregate?.deltas.runsCountDelta ?? 0) >= 0,
          )),
        ]),
        const SizedBox(height: 16),

        // Coach.AI Análise
        FigmaCoachAIBlock(
          child: loadingAnalysis
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : Text(
                  periodAnalysis?.status == PeriodAnalysisStatus.pending
                      ? 'Coach analisando seu período...'
                      : (periodAnalysis?.summary ?? 'Coach analisando seu período...'),
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
        if (bpm < 100) {
          z1++;
        } else if (bpm < 120) {
          z2++;
        } else if (bpm < 145) {
          z3++;
        } else if (bpm < 170) {
          z4++;
        } else {
          z5++;
        }
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
      } else {
        break;
      }
    }

    final totalMin = totalS ~/ 60;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    final totalTimeLabel = h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';

    return _HistoryStats(
      count: runs.length,
      runningCount: runningCount,
      totalKm: totalDistM / 1000,
      totalS: totalS,
      totalTimeLabel: totalTimeLabel,
      avgPaceLabel: avgPaceLabel,
      streakDays: streak,
      totalXp: totalXp,
      avgBpm: avgBpm,
      zoneDistribution: zoneDistribution,
      weeklyVolume: weeklyVolume,
    );
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

// ── Volume two-tone helpers ──────────────────────────────────────────────────

String _volumeTitle(_Period p) {
  switch (p) {
    case _Period.week: return 'VOLUME DIÁRIO';
    case _Period.month: return 'VOLUME SEMANAL';
    case _Period.threeMonths: return 'VOLUME MENSAL';
  }
}

String _volumeSubtitle(_Period p) {
  switch (p) {
    case _Period.week:
      return 'Km por dia da semana — planejado vs feito';
    case _Period.month:
      return 'Km por semana do mês — planejado vs feito';
    case _Period.threeMonths:
      return 'Km por mês — planejado vs feito';
  }
}

/// Constrói os buckets de volume baseado no período selecionado.
/// Para cada bucket, soma planned (do Plan) e executed (das Runs).
List<TwoToneBarData> _buildVolumeBuckets(
  _Period period,
  Plan? plan,
  List<Run> runs,
) {
  final now = DateTime.now();
  switch (period) {
    case _Period.week:
      return _bucketByDayOfWeek(now, plan, runs);
    case _Period.month:
      return _bucketByWeekOfMonth(now, plan, runs);
    case _Period.threeMonths:
      return _bucketByMonth(now, plan, runs);
  }
}

/// 7 buckets — Seg..Dom da semana atual.
List<TwoToneBarData> _bucketByDayOfWeek(DateTime now, Plan? plan, List<Run> runs) {
  // Domingo = 7 no padrão do plano, então mapeamos cronologicamente.
  const dayLabels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final mondayDate = DateTime(monday.year, monday.month, monday.day);

  // Sessão planejada para esta semana (se plano ativo cobrir esses dias).
  final plannedByDay = <int, double>{};
  if (plan != null && plan.isReady) {
    final daysFromStart = mondayDate.difference(plan.effectiveStartDate).inDays;
    final weekIdx = (daysFromStart / 7).floor();
    if (weekIdx >= 0 && weekIdx < plan.weeks.length) {
      for (final s in plan.weeks[weekIdx].sessions) {
        plannedByDay[s.dayOfWeek] = (plannedByDay[s.dayOfWeek] ?? 0) + s.distanceKm;
      }
    }
  }

  // Executed por dia (das runs desta semana).
  final executedByDay = <int, double>{};
  for (final r in runs) {
    final d = DateTime.tryParse(r.createdAt);
    if (d == null) continue;
    final localDate = DateTime(d.year, d.month, d.day);
    if (localDate.isBefore(mondayDate) ||
        localDate.isAfter(mondayDate.add(const Duration(days: 6)))) {
      continue;
    }
    final dow = localDate.weekday; // 1=Mon..7=Sun
    executedByDay[dow] = (executedByDay[dow] ?? 0) + r.distanceM / 1000;
  }

  return List.generate(7, (i) {
    final dow = i + 1;
    return TwoToneBarData(
      planned: plannedByDay[dow] ?? 0,
      executed: executedByDay[dow] ?? 0,
      label: dayLabels[i],
    );
  });
}

/// 4-5 buckets — semanas do mês atual.
List<TwoToneBarData> _bucketByWeekOfMonth(DateTime now, Plan? plan, List<Run> runs) {
  final firstOfMonth = DateTime(now.year, now.month, 1);
  final lastOfMonth = DateTime(now.year, now.month + 1, 0);
  final weekStarts = <DateTime>[];
  // Começa na segunda da semana que contém o dia 1.
  var cursor = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
  while (cursor.isBefore(lastOfMonth) ||
      cursor.isAtSameMomentAs(lastOfMonth)) {
    weekStarts.add(cursor);
    cursor = cursor.add(const Duration(days: 7));
  }

  return List.generate(weekStarts.length, (i) {
    final start = weekStarts[i];
    final end = start.add(const Duration(days: 6));
    double planned = 0;
    if (plan != null && plan.isReady) {
      final daysFromStart = start.difference(plan.effectiveStartDate).inDays;
      final weekIdx = (daysFromStart / 7).floor();
      if (weekIdx >= 0 && weekIdx < plan.weeks.length) {
        planned = plan.weeks[weekIdx].sessions
            .fold(0.0, (a, s) => a + s.distanceKm);
      }
    }
    double executed = 0;
    for (final r in runs) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) continue;
      final localDate = DateTime(d.year, d.month, d.day);
      if (localDate.isBefore(start) || localDate.isAfter(end)) continue;
      executed += r.distanceM / 1000;
    }
    return TwoToneBarData(
      planned: planned,
      executed: executed,
      label: 'S${i + 1}',
    );
  });
}

/// 3 buckets — últimos 3 meses (incluindo o atual).
List<TwoToneBarData> _bucketByMonth(DateTime now, Plan? plan, List<Run> runs) {
  const monthLabels = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
      'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
  return List.generate(3, (i) {
    final month = DateTime(now.year, now.month - (2 - i), 1);
    final monthEnd = DateTime(now.year, now.month - (2 - i) + 1, 0);
    double planned = 0;
    if (plan != null && plan.isReady) {
      for (var wi = 0; wi < plan.weeks.length; wi++) {
        final weekStart = plan.effectiveStartDate.add(Duration(days: wi * 7));
        if (weekStart.isBefore(month) || weekStart.isAfter(monthEnd)) {
          continue;
        }
        planned += plan.weeks[wi].sessions
            .fold(0.0, (a, s) => a + s.distanceKm);
      }
    }
    double executed = 0;
    for (final r in runs) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) continue;
      if (d.year != month.year || d.month != month.month) continue;
      executed += r.distanceM / 1000;
    }
    return TwoToneBarData(
      planned: planned,
      executed: executed,
      label: monthLabels[month.month - 1],
    );
  });
}

// ── Aba Corridas ─────────────────────────────────────────────────────────────

class _RunsListView extends StatelessWidget {
  final List<Run> runs;
  const _RunsListView({required this.runs});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: runs.length,
      itemBuilder: (_, i) {
        final run = runs[i];
        return Stack(
          children: [
            FigmaRunCard(
              typeLabel: run.type.toUpperCase(),
              dateLabel: _fmtDate(run.createdAt),
              distanceKm: run.distanceM / 1000,
              pace: run.avgPace ?? '--:--',
              duration: _fmtDuration(run.durationS),
              coachPreview: run.coachQuote ?? 'Sem análise gerada ainda',
              onTap: () => context.push('/history/run/${run.id}'),
            ),
            if (run.planSessionId == null)
              Positioned(
                top: 8,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      'FREE',
                      style: context.runninType.labelCaps.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

String _fmtDeltaPct(int? pct) {
  if (pct == null) return '--';
  final sign = pct > 0 ? '+' : '';
  return '$sign$pct%';
}

String _fmtDeltaBpm(int? bpm) {
  if (bpm == null) return '--';
  final sign = bpm > 0 ? '+' : '';
  return '$sign$bpm';
}

String _fmtDeltaInt(int? n) {
  if (n == null) return '--';
  final sign = n > 0 ? '+' : '';
  return '$sign$n';
}