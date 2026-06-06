import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/core/units/relative_period_label.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/biometrics/domain/run_zones.dart';
import 'package:runnin/features/history/data/period_analysis_remote_datasource.dart';
import 'package:runnin/features/history/data/stats_remote_datasource.dart';
import 'package:runnin/features/history/domain/entities/period_analysis.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';
import 'package:runnin/features/history/domain/entities/stats_breakdown.dart';
import 'package:runnin/features/profile/presentation/pages/health/zones_utils.dart';
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

enum _ContentTab { data, runs }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _remote = RunRemoteDatasource();
  final _planRemote = PlanRemoteDatasource();
  final _userRemote = UserRemoteDatasource();
  final _biometricRemote = BiometricRemoteDatasource();
  List<Run>? _allRuns;
  Plan? _plan;
  UserProfile? _profile;
  BiometricSummary? _biometricSummary;
  bool _loading = true;
  String? _error;
  _Period _period = _Period.month;
  _ContentTab _tab = _ContentTab.data;
  /// Offset do período exibido em relação ao corrente:
  ///   0 = período atual (semana/mês/3-meses corrente)
  ///  -1 = anterior (semana passada, mês passado, ou 3 meses anteriores)
  /// Sempre <= 0 (não navegamos pro futuro). Reset pra 0 ao trocar `_period`.
  int _periodCursor = 0;
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

  /// Janela civil [start, end) do período selecionado, deslocada por
  /// `_periodCursor`. Convenção: end é exclusivo — bate com `buildBuckets`
  /// do backend ([server] get-stats-breakdown.use-case.ts) pra alinhamento.
  ({DateTime start, DateTime end}) _periodRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.week:
        // Segunda da semana civil corrente (weekday: Mon=1..Sun=7).
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final start = monday.add(Duration(days: _periodCursor * 7));
        return (start: start, end: start.add(const Duration(days: 7)));
      case _Period.month:
        final monthStart = DateTime(today.year, today.month + _periodCursor, 1);
        final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
        return (start: monthStart, end: monthEnd);
      case _Period.threeMonths:
        // 3 meses civis terminando no mês corrente (com cursor: -1 = 3 meses
        // imediatamente anteriores aos 3 atuais).
        final endMonth = DateTime(
          today.year,
          today.month + 1 + _periodCursor * 3,
          1,
        );
        final startMonth = DateTime(endMonth.year, endMonth.month - 3, 1);
        return (start: startMonth, end: endMonth);
    }
  }

  String _fmtRangeLabel() {
    // Label relativo ("ESTA SEMANA", "MÊS PASSADO", "HÁ N TRIMESTRES")
    // alimentado por _period + _periodCursor — fallback ao formato
    // DE..ATÉ antigo se algo inesperado acontecer.
    final kind = switch (_period) {
      _Period.week => PeriodKind.week,
      _Period.month => PeriodKind.month,
      _Period.threeMonths => PeriodKind.threeMonths,
    };
    return formatRelativePeriod(kind, _periodCursor);
  }

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
    // Backend só conhece o período corrente — em janela histórica
    // (cursor != 0) zeramos pra cair no fallback client-side.
    if (_periodCursor != 0) {
      setState(() => _aggregate = null);
      return;
    }
    try {
      final result = await _statsDatasource.getAggregate(_periodKey);
      if (mounted) setState(() => _aggregate = result);
    } catch (_) {
      // Sem aggregate, fallback nos deltas hardcoded.
    }
  }

  Future<void> _loadBreakdown() async {
    if (!mounted) return;
    if (_periodCursor != 0) {
      setState(() => _breakdown = null);
      return;
    }
    try {
      final result = await _statsDatasource.getBreakdown(_periodKey);
      if (mounted) setState(() => _breakdown = result);
    } catch (_) {
      // Sem breakdown, _DataView faz fallback no cálculo client-side.
    }
  }

  Future<void> _loadPeriodAnalysis() async {
    if (!mounted) return;
    if (_periodCursor != 0) {
      setState(() {
        _periodAnalysis = null;
        _loadingAnalysis = false;
      });
      return;
    }
    setState(() => _loadingAnalysis = true);
    try {
      final result = await _periodAnalysisDatasource.getPeriodAnalysis(_analysisLimit);
      if (mounted) setState(() { _periodAnalysis = result; _loadingAnalysis = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAnalysis = false);
    }
  }

  void _reloadPeriodData() {
    _loadPeriodAnalysis();
    _loadAggregate();
    _loadBreakdown();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Carrega runs, plano, profile e summary em paralelo. Tudo exceto runs
      // pode falhar (freemium / user sem plano / sem biometria) — não bloqueia
      // a listagem. Profile+summary alimentam o cálculo de zonas cardíacas
      // com ranges Karvonen reais em vez dos buckets hardcoded antigos.
      // getSummary tem retorno não-nullable; envolve em Future.value(null) no
      // catch pra encaixar no Future.wait paralelo abaixo.
      Future<BiometricSummary?> summaryF() async {
        try { return await _biometricRemote.getSummary(windowDays: 30); }
        catch (_) { return null; }
      }
      final results = await Future.wait<dynamic>([
        _remote.listRuns(limit: 200),
        _planRemote.getCurrentPlan().catchError((_) => null),
        _userRemote.getMe().catchError((_) => null),
        summaryF(),
      ]);
      final runs = results[0] as List<Run>;
      final plan = results[1] as Plan?;
      final profile = results[2] as UserProfile?;
      final summary = results[3] as BiometricSummary?;
      if (mounted) {
        setState(() {
          _allRuns = runs;
          _plan = plan;
          _profile = profile;
          _biometricSummary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corridas.'; _loading = false; });
    }
  }

  List<Run> get _filteredRuns {
    if (_allRuns == null) return [];
    final r = _periodRange();
    return _allRuns!
        .where((run) => run.status == 'completed')
        // distanceM >= 100m exclui run "stationary" (start sem GPS / abandono
        // mascarado como completed) que poluía agregados — uma run de 38min
        // com 0km gerava pace médio absurdo (23min/km) ao entrar na conta.
        // Mesma regra agora aplicada server-side em findByDateRange.
        .where((run) => run.distanceM >= 100)
        .where((run) {
          final d = DateTime.tryParse(run.createdAt);
          if (d == null) return false;
          // Compara em local time pra bater com a fronteira civil [start, end).
          final local = d.toLocal();
          return !local.isBefore(r.start) && local.isBefore(r.end);
        })
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
            // Submenu de CONTEÚDO em cima (DADOS/CORRIDAS)...
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SegmentedTabBar(
                fontSize: 12,
                tabs: const ['DADOS', 'CORRIDAS'],
                selectedIndex: _ContentTab.values.indexOf(_tab),
                onChanged: (i) {
                  setState(() => _tab = _ContentTab.values[i]);
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
                  setState(() {
                    _period = _Period.values[i];
                    // Resetar cursor pra "atual" quando troca de tipo de
                    // período — o offset não traduz semanticamente (cursor
                    // = -1 em SEMANA é 1 semana, em 3 MESES é 3 meses).
                    _periodCursor = 0;
                  });
                  _reloadPeriodData();
                },
              ),
            ),
            const SizedBox(height: 8),
            // Range exibido (janela civil) + setas pra navegar pra trás.
            // Tap no label volta pro período corrente.
            _PeriodRangeBar(
              label: _fmtRangeLabel(),
              canGoForward: _periodCursor < 0,
              onPrev: () {
                setState(() => _periodCursor--);
                _reloadPeriodData();
              },
              onNext: _periodCursor < 0
                  ? () {
                      setState(() => _periodCursor++);
                      _reloadPeriodData();
                    }
                  : null,
              onResetToCurrent: _periodCursor < 0
                  ? () {
                      setState(() => _periodCursor = 0);
                      _reloadPeriodData();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
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

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: _load,
      child: _tab == _ContentTab.data
          ? _DataView(
              runs: runs,
              plan: _plan,
              period: _period,
              range: _periodRange(),
              showDeltas: _periodCursor == 0,
              periodAnalysis: _periodAnalysis,
              loadingAnalysis: _loadingAnalysis,
              aggregate: _aggregate,
              breakdown: _breakdown,
              profile: _profile,
              biometricSummary: _biometricSummary,
            )
          : _RunsListView(runs: runs, plan: _plan),
    );
  }
}

// ── Aba Dados ───────────────────────────────────────────────────────────────

class _DataView extends StatelessWidget {
  final List<Run> runs;
  final Plan? plan;
  final _Period period;
  /// Janela civil [start, end) usada pra filtrar runs e construir buckets.
  /// Mantém os gráficos wired com o range selecionado pelo seletor de período.
  final ({DateTime start, DateTime end}) range;
  /// Esconde a Row de FigmaStatTileWithDelta quando navegando histórico
  /// (cursor != 0). Deltas só fazem sentido pro período corrente, já que o
  /// backend compara contra "período imediatamente anterior".
  final bool showDeltas;
  final PeriodAnalysis? periodAnalysis;
  final bool loadingAnalysis;
  final StatsAggregate? aggregate;
  final StatsBreakdown? breakdown;
  /// Profile + summary alimentam o cálculo Karvonen das zonas (ranges
  /// reais por user). Null = cai pro fallback de buckets fixos.
  final UserProfile? profile;
  final BiometricSummary? biometricSummary;
  const _DataView({
    required this.runs,
    required this.plan,
    required this.period,
    required this.range,
    this.showDeltas = true,
    this.periodAnalysis,
    this.loadingAnalysis = false,
    this.aggregate,
    this.breakdown,
    this.profile,
    this.biometricSummary,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs); // fallback + zonas + deltas
    final p = context.runninPalette;
    final bd = breakdown?.stats;

    // Valores do PERÍODO selecionado: prioriza breakdown (BE); fallback no
    // cálculo client-side. Todos "wired".
    final corridas = '${bd?.runs ?? stats.count}';
    final volumeKm = (bd?.totalDistanceKm ?? stats.totalKm).toStringAsFixed(1);
    final tempoTotal = bd?.totalTimeLabel ?? stats.totalTimeLabel;
    final pace = bd?.avgPace ?? stats.avgPaceLabel;
    final bpmMed = (bd?.avgBpm ?? stats.avgBpm)?.toString() ?? '--';
    final bpmMax = bd?.maxBpm?.toString() ?? '--';
    final calorias = bd != null
        ? '${bd.calories}'
        : (stats.calories != null ? '${stats.calories}' : '--');
    final distMedia = (bd?.avgDistanceKm ??
            (stats.count > 0 ? stats.totalKm / stats.count : 0))
        .toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Stats do período — cards com outline, 2 por linha, cores por métrica.
        Row(children: [
          Expanded(child: _HeroStat(label: 'CORRIDAS', value: corridas, color: p.text)),
          const SizedBox(width: 12),
          Expanded(child: _HeroStat(label: 'DISTÂNCIA TOTAL', value: volumeKm, unit: 'km', color: p.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _HeroStat(label: 'TEMPO TOTAL', value: tempoTotal, color: p.text)),
          const SizedBox(width: 12),
          Expanded(child: _HeroStat(label: 'PACE MÉDIO', value: pace, unit: '/km', color: p.secondary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _HeroStat(label: 'BPM MÉDIO', value: bpmMed, unit: 'bpm', color: p.primary)),
          const SizedBox(width: 12),
          Expanded(child: _HeroStat(label: 'BPM MÁXIMO', value: bpmMax, unit: 'bpm', color: p.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _HeroStat(label: 'CALORIAS', value: calorias, unit: 'kcal', color: p.text)),
          const SizedBox(width: 12),
          Expanded(child: _HeroStat(label: 'DIST. MÉDIA', value: distMedia, unit: 'km/corr', color: p.text)),
        ]),
        const SizedBox(height: 20),

        // Seção Zonas Cardíacas — barra de overview + cards Z1-Z5 detalhados.
        // Cards reusam FigmaZoneCard (mesmo widget de perfil/saúde/zonas) com
        // ranges Karvonen do user (profile.restingBpm/maxBpm; fallback 60-190).
        if (stats.zoneDistribution.isNotEmpty)
          ChartPanel(
            title: 'ZONAS CARDÍACAS',
            subtitle: 'Distribuição de tempo nas zonas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FigmaZoneDistributionBar(
                  zonePercentages: stats.zoneDistribution,
                ),
                if (stats.zoneCards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (var i = 0; i < stats.zoneCards.length; i++) ...[
                    FigmaZoneCard(
                      zoneNumber: stats.zoneCards[i].number,
                      zoneLabel: stats.zoneCards[i].label,
                      bpmRange:
                          '${stats.zoneCards[i].minBpm}-${stats.zoneCards[i].maxBpm} bpm',
                      percent: stats.zoneCards[i].pctTime,
                      zoneColor: stats.zoneCards[i].color,
                    ),
                    if (i < stats.zoneCards.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ],
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
                : _buildVolumeBuckets(period, range, plan, runs),
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
        // Em janela histórica (showDeltas=false) escondemos a seção inteira:
        // o backend não sabe comparar contra "período anterior" de uma janela
        // que não é a corrente.
        if (showDeltas) ...[
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
      ],
    );
  }

  _HistoryStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _HistoryStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    // Calorias: server enriquece cada run em CompleteRunUseCase via MET ×
    // peso × tempo. Runs antigas (retroativas) podem ter null — soma só
    // o que estiver disponível pra ficar consistente com o /stats/breakdown.
    final totalCalories = runs.fold<int>(0, (s, r) => s + (r.calories ?? 0));
    final runningCount = runs.where((r) => r.status == 'completed').length;

    // Pace médio em segundos/km — weighted por distância (totalS / totalDistKm).
    // Antes calculávamos média aritmética dos paces individuais, que é
    // matematicamente errado: uma run curta lenta puxava o agregado pra
    // cima na mesma proporção de uma longa rápida. Agora a duração total
    // dividida pela distância total dá o pace real do volume completo.
    int? avgPaceSec;
    if (totalDistM > 0 && totalS > 0) {
      avgPaceSec = (totalS * 1000 / totalDistM).round();
    }

    final avgPaceLabel = avgPaceSec == null
        ? '--:--'
        : '${avgPaceSec ~/ 60}:${(avgPaceSec % 60).toString().padLeft(2, '0')}';

    // BPM médio — antes filtrávamos por r.avgPace != null (bug de
    // copy-paste): runs sem GPS mas com sensor BPM ficavam fora da conta.
    // O filtro correto é direto pelo campo que estamos agregando.
    int? avgBpm;
    final runsWithBpmValid = runs.where((r) => r.avgBpm != null && r.avgBpm! > 0).toList();
    if (runsWithBpmValid.isNotEmpty) {
      final totalBpm = runsWithBpmValid.fold<int>(0, (s, r) => s + r.avgBpm!);
      avgBpm = totalBpm ~/ runsWithBpmValid.length;
    }

    // Zonas cardíacas — distribuição de tempo ponderada pelos splits.
    // Antes usávamos count-based (cada run "vota" numa zona pelo avgBpm
    // geral), o que enviesava pra Z3 em qualquer corrida moderada. Agora:
    //   1. Se o profile/summary fecharem o Karvonen (resting+max válidos),
    //      classificamos cada split por avgBpm na zona Karvonen real e
    //      somamos durationS.
    //   2. Fallback (sem range válido): bucket por faixas fixas com tempo
    //      total da run, não conta de runs — pelo menos não enviesa por
    //      tamanho.
    final range = resolveBpmRange(profile: profile, summary: biometricSummary);
    final karvonenZones = computeHealthZones(restingBpm: range.resting, maxBpm: range.max);
    final zoneTimes = List<int>.filled(5, 0);
    var anyBpm = false;
    for (final r in runs) {
      // Se tem splits, prefere os splits (mais granular). Senão, fallback
      // pro avgBpm da run inteira × durationS.
      if (r.splits.isNotEmpty) {
        for (final s in r.splits) {
          final bpm = s.avgBpm;
          if (bpm == null || bpm <= 0 || s.durationS <= 0) continue;
          anyBpm = true;
          zoneTimes[_bucketBpm(bpm, karvonenZones)] += s.durationS;
        }
      } else if (r.avgBpm != null && r.avgBpm! > 0 && r.durationS > 0) {
        anyBpm = true;
        zoneTimes[_bucketBpm(r.avgBpm!, karvonenZones)] += r.durationS;
      }
    }
    final List<double> zoneDistribution;
    final List<HealthZone> zoneCards;
    if (anyBpm) {
      final totalTime = zoneTimes.fold<int>(0, (a, b) => a + b);
      final pcts = totalTime > 0
          ? zoneTimes.map((t) => (t / totalTime) * 100).toList()
          : <double>[0, 0, 0, 0, 0];
      zoneDistribution = pcts;
      // Cards reusam a definição (cor + range BPM) do Karvonen ou fallback
      // de buckets fixos quando o range não é válido.
      final base = karvonenZones.isNotEmpty
          ? karvonenZones
          : _fallbackZonesForCards();
      zoneCards = [
        for (var i = 0; i < base.length; i++)
          HealthZone(
            number: base[i].number,
            label: base[i].label,
            description: base[i].description,
            minBpm: base[i].minBpm,
            maxBpm: base[i].maxBpm,
            color: base[i].color,
            pctTime: pcts[i],
          ),
      ];
    } else {
      zoneDistribution = const [];
      zoneCards = const [];
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
      calories: totalCalories,
      zoneDistribution: zoneDistribution,
      zoneCards: zoneCards,
      weeklyVolume: weeklyVolume,
    );
  }

  /// Mapeia um BPM em uma das 5 zonas. Usa Karvonen quando [zones] está
  /// disponível (range válido por user); senão cai em buckets fixos
  /// 100/120/145/170 (mantém compatibilidade com a lógica antiga).
  int _bucketBpm(int bpm, List<HealthZone> zones) {
    if (zones.isEmpty) {
      if (bpm < 100) return 0;
      if (bpm < 120) return 1;
      if (bpm < 145) return 2;
      if (bpm < 170) return 3;
      return 4;
    }
    for (var i = 0; i < zones.length; i++) {
      if (bpm < zones[i].maxBpm || i == zones.length - 1) return i;
    }
    return zones.length - 1;
  }

  /// Fallback de cards Z1-Z5 quando o profile não fecha o Karvonen. Usa
  /// os mesmos labels/cores da página de zonas mas com ranges fixos —
  /// melhor que sumir os cards inteiros.
  List<HealthZone> _fallbackZonesForCards() {
    // Reusa computeHealthZones com restingBpm=60 e maxBpm=190 (genéricos)
    // pra ter os mesmos labels+cores; o range BPM é só ilustrativo.
    return computeHealthZones(restingBpm: 60, maxBpm: 190);
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
  /// Soma de calorias (kcal) das runs do período. Null = sem dado (todas
  /// as runs sem `calories` enriquecido); 0 é resultado válido.
  final int? calories;
  final List<double> zoneDistribution;
  /// Cards Z1-Z5 com nome+range BPM+pctTime preenchidos, renderizados
  /// abaixo da barra. Vazio = sem BPM válido no período (e a barra
  /// também fica oculta).
  final List<HealthZone> zoneCards;
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
    this.calories,
    this.zoneDistribution = const [],
    this.zoneCards = const [],
    required this.weeklyVolume,
  });

  factory _HistoryStats.empty() => const _HistoryStats(
    count: 0, runningCount: 0, totalKm: 0, totalS: 0, totalTimeLabel: '0m',
    avgPaceLabel: '--:--', streakDays: 0, totalXp: 0,
    avgBpm: null, calories: null, zoneDistribution: [], zoneCards: [], weeklyVolume: [],
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

/// Constrói os buckets de volume baseado no período selecionado, usando a
/// janela civil [range.start, range.end). Cada bucket soma planned (do Plan)
/// e executed (das Runs) restritos ao range. Wired com `_periodRange()` da
/// HistoryPage pra que filtro/label/gráficos vejam o mesmo intervalo.
List<TwoToneBarData> _buildVolumeBuckets(
  _Period period,
  ({DateTime start, DateTime end}) range,
  Plan? plan,
  List<Run> runs,
) {
  switch (period) {
    case _Period.week:
      return _bucketByDayOfWeek(range, plan, runs);
    case _Period.month:
      return _bucketByWeekOfMonth(range, plan, runs);
    case _Period.threeMonths:
      return _bucketByMonth(range, plan, runs);
  }
}

/// 7 buckets — Seg..Dom da semana civil definida por [range].
/// Range.start é a segunda da semana (vide `_periodRange`).
List<TwoToneBarData> _bucketByDayOfWeek(
  ({DateTime start, DateTime end}) range,
  Plan? plan,
  List<Run> runs,
) {
  const dayLabels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  final monday = DateTime(range.start.year, range.start.month, range.start.day);

  // Sessão planejada para a semana do plano correspondente a esta semana
  // civil (se houver). Pode dar 0 quando range está fora do mesociclo.
  final plannedByDay = <int, double>{};
  if (plan != null && plan.isReady) {
    final daysFromStart = monday.difference(plan.effectiveStartDate).inDays;
    final weekIdx = (daysFromStart / 7).floor();
    if (weekIdx >= 0 && weekIdx < plan.weeks.length) {
      for (final s in plan.weeks[weekIdx].sessions) {
        plannedByDay[s.dayOfWeek] = (plannedByDay[s.dayOfWeek] ?? 0) + s.distanceKm;
      }
    }
  }

  // Executed por dia (runs dentro do range).
  final executedByDay = <int, double>{};
  for (final r in runs) {
    final d = DateTime.tryParse(r.createdAt);
    if (d == null) continue;
    final local = d.toLocal();
    if (local.isBefore(range.start) || !local.isBefore(range.end)) continue;
    final dow = local.weekday; // 1=Mon..7=Sun
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

/// Buckets por semana civil que intersectam o mês [range].
List<TwoToneBarData> _bucketByWeekOfMonth(
  ({DateTime start, DateTime end}) range,
  Plan? plan,
  List<Run> runs,
) {
  final firstOfMonth = range.start;
  // end é exclusivo (primeiro dia do mês seguinte) — último inclusivo:
  final lastOfMonth = range.end.subtract(const Duration(days: 1));
  final weekStarts = <DateTime>[];
  // Começa na segunda da semana civil que contém o dia 1 do mês.
  var cursor = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
  while (!cursor.isAfter(lastOfMonth)) {
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
      final local = d.toLocal();
      final localDate = DateTime(local.year, local.month, local.day);
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

/// 3 buckets — meses civis cobertos por [range] (range cobre exatamente
/// 3 meses pelo _periodRange).
List<TwoToneBarData> _bucketByMonth(
  ({DateTime start, DateTime end}) range,
  Plan? plan,
  List<Run> runs,
) {
  const monthLabels = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
      'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
  return List.generate(3, (i) {
    final month = DateTime(range.start.year, range.start.month + i, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(days: 1));
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
      final local = d.toLocal();
      if (local.year != month.year || local.month != month.month) continue;
      executed += r.distanceM / 1000;
    }
    return TwoToneBarData(
      planned: planned,
      executed: executed,
      label: monthLabels[month.month - 1],
    );
  });
}

// ── Barra de período (label de range + setas de navegação) ──────────────────

/// Barra discreta abaixo dos chips SEMANA/MÊS/3 MESES mostrando o range
/// civil exibido. Setas pra navegar pra semanas/meses passados; tap no label
/// volta pra "atual" quando o user está navegando histórico.
class _PeriodRangeBar extends StatelessWidget {
  final String label;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onResetToCurrent;

  const _PeriodRangeBar({
    required this.label,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
    required this.onResetToCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_left, color: palette.muted),
            tooltip: 'Período anterior',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onResetToCurrent,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(
                  label,
                  style: type.bodyXs.copyWith(
                    color: palette.muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.chevron_right,
              color: canGoForward ? palette.muted : palette.muted.withValues(alpha: 0.3),
            ),
            tooltip: canGoForward ? 'Período seguinte' : 'Sem futuro',
          ),
        ],
      ),
    );
  }
}

// ── Aba Corridas ─────────────────────────────────────────────────────────────

class _RunsListView extends StatelessWidget {
  final List<Run> runs;
  final Plan? plan;
  const _RunsListView({required this.runs, this.plan});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: runs.length,
      itemBuilder: (_, i) {
        final run = runs[i];
        return _RunHistoryCard(
          run: run,
          plan: plan,
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
  final Plan? plan;
  final VoidCallback onTap;
  const _RunHistoryCard({required this.run, this.plan, required this.onTap});

  /// Posição da sessão no plano: (semana, índice 1-based, total da semana).
  /// Null = corrida livre (sem planSessionId) ou sessão não encontrada no plano.
  ({int week, int idx, int total})? _planPos() {
    final pid = run.planSessionId;
    if (pid == null || plan == null) return null;
    for (final w in plan!.weeks) {
      final ordered = [...w.sessions]
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
      final i = ordered.indexWhere((s) => s.id == pid);
      if (i >= 0) {
        return (week: w.weekNumber, idx: i + 1, total: ordered.length);
      }
    }
    return null;
  }

  // Data no formato brasileiro: dd/MM/yyyy (ex.: 21/05/2026).
  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtDur(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0
        ? '${h}h${m.toString().padLeft(2, '0')}'
        : '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final pos = _planPos();
    final isPlan = pos != null;
    final accent = isPlan ? palette.primary : palette.secondary;
    final actual = run.distanceM / 1000;
    final actualStr = actual.toStringAsFixed(actual % 1 == 0 ? 0 : 1);
    final title = run.type;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo: badge (esq) + título/data · volume realizado (dir).
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge: SEM{semana} + sessão {i}/{n} (cyan, sessão do plano)
                // ou "FREE" (laranja, corrida extra/livre).
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: isPlan
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SEM ${pos.week}',
                              style: type.labelCaps.copyWith(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${pos.idx}/${pos.total}',
                              style: type.labelCaps.copyWith(
                                color: accent,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'FREE',
                          style: type.labelCaps.copyWith(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Título da sessão + data abaixo.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.labelMd.copyWith(
                          color: palette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtDate(run.createdAt),
                        style: type.labelCaps.copyWith(
                          color: palette.muted,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Volume realizado: número laranja grande + "KM" cinza.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      actualStr,
                      style: type.dataMd.copyWith(
                        color: palette.secondary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'KM',
                      style: type.labelCaps.copyWith(
                        color: palette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Divisor horizontal fino.
            Container(height: 1, color: palette.border.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            // Métricas: PACE · DURAÇÃO · BPM AVG · XP.
            Row(
              children: [
                Expanded(child: _RunStat(label: 'PACE', value: run.avgPace ?? '--:--', color: palette.secondary)),
                Expanded(child: _RunStat(label: 'DURAÇÃO', value: _fmtDur(run.durationS), color: palette.text)),
                Expanded(child: _RunStat(label: 'BPM AVG', value: run.avgBpm?.toString() ?? '--', color: palette.primary)),
                Expanded(child: _RunStat(label: 'XP', value: '${run.xpEarned ?? 0}', color: palette.primary)),
              ],
            ),
            // Nota do coach (avaliação da sessão).
            if ((run.coachQuote ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                run.coachQuote!.trim(),
                style: type.bodySm.copyWith(
                  color: palette.muted,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RunStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: type.dataXs.copyWith(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: type.labelCaps.copyWith(
            color: palette.muted,
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Stat principal do Histórico (referência PNG): label pequeno + valor grande
/// colorido (+ unidade). Usado em grade de 2 por linha.
class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _HeroStat({
    required this.label,
    required this.value,
    this.unit = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Valor grande (cor da métrica) no topo.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: type.dataMd.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    letterSpacing: -0.5,
                  ),
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
          const SizedBox(height: 6),
          // Label embaixo, em caixa-alta suave.
          Text(
            label,
            style: type.labelCaps.copyWith(
              color: palette.muted,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
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