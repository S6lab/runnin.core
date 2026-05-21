import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/history/data/benchmark_remote_datasource.dart' show BenchmarkRemoteDatasource;
import 'package:runnin/features/history/data/period_analysis_remote_datasource.dart';
import 'package:runnin/features/history/data/stats_remote_datasource.dart';
import 'package:runnin/features/history/domain/entities/period_analysis.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';
import 'package:runnin/features/history/domain/entities/stats_breakdown.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/chart_panel.dart';
import 'package:runnin/shared/widgets/two_tone_bar_chart.dart';
import 'package:runnin/shared/widgets/two_line_chart.dart';
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
  final bool _benchmarkLoading = false;
  double? _benchmarkPercentile;
  List<BenchmarkRow> _benchmarkTableData = [];
  bool _benchmarkEmpty = false;
  final _benchmarkDatasource = BenchmarkRemoteDatasource();
  final _periodAnalysisDatasource = PeriodAnalysisRemoteDatasource();
  PeriodAnalysis? _periodAnalysis;
  bool _loadingAnalysis = false;
  final _statsDatasource = StatsRemoteDatasource();
  StatsAggregate? _aggregate;
  StatsBreakdown? _breakdown;

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
    _loadBreakdown();
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

  Future<void> _loadBreakdown() async {
    if (!mounted) return;
    try {
      final result = await _statsDatasource.getBreakdown(_periodKey);
      if (mounted) setState(() => _breakdown = result);
    } catch (_) {
      // Sem breakdown, _DataView faz fallback no cálculo client-side.
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
            // Submenu de CONTEÚDO em cima (DADOS/CORRIDAS/BENCH)...
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SegmentedTabBar(
                fontSize: 12,
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
            const SizedBox(height: 12),
            // ...e filtro de PERÍODO embaixo (SEMANA/MÊS/3 MESES).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SegmentedTabBar(
                outlineSelection: true,
                tabs: const ['SEMANA', 'MÊS', '3 MESES'],
                selectedIndex: _Period.values.indexOf(_period),
                onChanged: (i) {
                  setState(() => _period = _Period.values[i]);
                  _loadPeriodAnalysis();
                  _loadAggregate();
                  _loadBreakdown();
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

    // DADOS sempre renderiza: os gráficos mostram o PLANEJADO (do plano) +
    // realizado, mesmo sem nenhuma corrida no período. O estado vazio só faz
    // sentido na aba CORRIDAS (lista de corridas).
    if (runs.isEmpty && _tab == _ContentTab.runs) {
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
          ? _DataView(runs: runs, plan: _plan, period: _period, periodAnalysis: _periodAnalysis, loadingAnalysis: _loadingAnalysis, aggregate: _aggregate, breakdown: _breakdown)
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
  final StatsBreakdown? breakdown;
  const _DataView({required this.runs, required this.plan, required this.period, this.periodAnalysis, this.loadingAnalysis = false, this.aggregate, this.breakdown});

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs); // fallback + zonas + deltas
    final p = context.runninPalette;
    final bd = breakdown?.stats;

    // Valores: prioriza breakdown (BE); fallback no cálculo client-side.
    final volumeKm = (bd?.totalDistanceKm ?? stats.totalKm).toStringAsFixed(1);
    final pace = bd?.avgPace ?? stats.avgPaceLabel;
    final nivel = bd != null ? '${bd.level}' : '--';
    final nivelNome = bd?.levelName ?? '';
    final bpmMed = (bd?.avgBpm ?? stats.avgBpm)?.toString() ?? '--';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Stats principais (referência: PNG /dados) — valores grandes, cores
        // alternadas (cyan/laranja) em disposição zigue-zague.
        _HeroStat(label: 'VOLUME', value: volumeKm, unit: 'km', color: p.primary, alignRight: true),
        const SizedBox(height: 18),
        _HeroStat(label: 'PACE MÉDIO', value: pace, unit: '/km', color: p.secondary, alignRight: true),
        const SizedBox(height: 18),
        _HeroStat(label: 'FC MÉDIA', value: bpmMed, unit: 'bpm', color: p.primary, alignRight: false),
        const SizedBox(height: 18),
        _HeroStat(label: 'ELEVAÇÃO', value: '+${runs.fold<double>(0, (s, r) => s + (r.elevationGain ?? 0)).round()}', unit: 'm', color: p.secondary, alignRight: true),
        const SizedBox(height: 18),
        _HeroStat(label: 'NÍVEL', value: nivel, unit: nivelNome, color: p.primary, alignRight: true),
        const SizedBox(height: 20),

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

        // Volume acumulado no período: barras paralelas planejado vs
        // realizado por dia/semana/mês (do breakdown do BE; fallback no
        // cálculo client-side enquanto carrega).
        ChartPanel(
          title: 'VOLUME ACUMULADO NO PERÍODO',
          subtitle: _volumeSubtitle(period),
          height: 200,
          child: TwoToneBarChart(
            data: breakdown != null
                ? breakdown!.volume
                    .map((b) => TwoToneBarData(
                          planned: b.plannedKm,
                          executed: b.realizedKm,
                          label: b.label,
                        ))
                    .toList()
                : _buildVolumeBuckets(period, plan, runs),
          ),
        ),
        const SizedBox(height: 16),

        // Pace do período: 2 linhas (projetado vs médio) por bucket.
        ChartPanel(
          title: 'PACE DO PERÍODO',
          subtitle: _paceSubtitle(period),
          height: 200,
          child: TwoLineChart(
            data: (breakdown?.pace ?? [])
                .map((b) => TwoLineData(
                      label: b.label,
                      lineA: b.projectedPaceSec?.toDouble(),
                      lineB: b.avgPaceSec?.toDouble(),
                    ))
                .toList(),
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

String _paceSubtitle(_Period p) {
  switch (p) {
    case _Period.week:
      return 'Pace por dia — projetado vs médio';
    case _Period.month:
      return 'Pace por semana do mês — projetado vs médio';
    case _Period.threeMonths:
      return 'Pace por mês — projetado vs médio';
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: runs.length,
      itemBuilder: (_, i) {
        final run = runs[i];
        return _RunHistoryCard(
          run: run,
          onTap: () => context.push('/history/run/${run.id}'),
        );
      },
    );
  }
}

/// Card de corrida no histórico (referência: PNG /corridas).
/// Esquerda: badge da distância planejada (cyan; laranja + "FREE" p/ corrida
/// livre). Direita: distância REAL grande em laranja. Embaixo: pace, FC e
/// ganho de elevação em cyan.
class _RunHistoryCard extends StatelessWidget {
  final Run run;
  final VoidCallback onTap;
  const _RunHistoryCard({required this.run, required this.onTap});

  String _badgeNumber() {
    final t = run.targetDistance;
    if (t != null) {
      final n = double.tryParse(t.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (n != null && n > 0) return n.toStringAsFixed(0);
    }
    return (run.distanceM / 1000).round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final isFree = run.planSessionId == null;
    final accent = isFree ? palette.secondary : palette.primary;
    final actual = run.distanceM / 1000;
    final actualStr = actual.toStringAsFixed(actual % 1 == 0 ? 0 : 1);
    final pace = run.avgPace ?? '--:--';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: palette.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge: distância planejada (ou alvo/real p/ livre).
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    border: Border.all(color: accent, width: 1.4),
                  ),
                  child: Text(
                    _badgeNumber(),
                    style: type.dataXs.copyWith(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: isFree
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: palette.secondary.withValues(alpha: 0.12),
                            ),
                            child: Text(
                              'FREE',
                              style: type.labelCaps.copyWith(
                                color: palette.secondary,
                                fontSize: 10,
                                letterSpacing: 1.0,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // Distância REAL (km) — destaque laranja.
                Text(
                  actualStr,
                  style: type.dataMd.copyWith(
                    color: palette.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Linha de métricas: pace à ESQUERDA em LARANJA; FC e ganho de
            // elevação ao CENTRO em CYAN (referência: cards canônicos).
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RunMetric(value: pace, color: palette.secondary),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (run.avgBpm != null)
                        _RunMetric(value: '${run.avgBpm}', color: palette.primary),
                      if (run.avgBpm != null && run.elevationGain != null)
                        const SizedBox(width: 28),
                      if (run.elevationGain != null)
                        _RunMetric(
                          value: '+${run.elevationGain!.round()}',
                          color: palette.primary,
                        ),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunMetric extends StatelessWidget {
  final String value;
  final Color color;
  const _RunMetric({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: context.runninType.bodyMd.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Stat principal do Histórico (referência PNG): label pequeno + valor grande
/// colorido (+ unidade), alinhado à esquerda ou direita (disposição zigue-zague).
class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool alignRight;
  const _HeroStat({
    required this.label,
    required this.value,
    this.unit = '',
    required this.color,
    this.alignRight = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: type.labelCaps.copyWith(
              color: palette.muted,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: type.dataMd.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 34,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: type.labelCaps.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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