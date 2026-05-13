import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/chart_panel.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';
import 'package:runnin/shared/widgets/loading_widget.dart';
import 'package:runnin/shared/widgets/error_state_widget.dart';
import 'package:runnin/shared/widgets/empty_state_widget.dart';

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
            Row(
              children: [
                const Expanded(child: AppPageHeader(title: 'HISTÓRICO')),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: () => context.push('/benchmark'),
                    child: const Text('BENCHMARK'),
                  ),
                ),
              ],
            ),
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
      return const LoadingWidget(
        fullScreen: true,
        message: 'Carregando histórico...',
      );
    }
    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _load,
        fullScreen: true,
        icon: Icons.error_outline,
      );
    }

    final runs = _filteredRuns;

    if (runs.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.directions_run_outlined,
        title: 'Nenhuma corrida no período',
        subtitle: 'Comece sua primeira corrida para ver suas estatísticas e evolução aqui.',
        fullScreen: true,
      );
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
        // Aggregated metrics grid
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

        // HR Zones
        if (stats.hasHeartRateData)
          ChartPanel(
            title: 'ZONAS CARDÍACAS',
            subtitle: 'Distribuição de BPM por zona de esforço',
            child: _HrZonesChart(zones: stats.hrZones),
          ),
        if (stats.hasHeartRateData)
          const SizedBox(height: 16),

        // Weekly volume chart
        if (stats.weeklyVolume.isNotEmpty)
          ChartPanel(
            title: 'VOLUME SEMANAL',
            subtitle: 'Km total por semana — carga de treino progressiva',
            child: SimpleBarChart(
              values: stats.weeklyVolume.map((e) => e.km).toList(),
              labels: stats.weeklyVolume.map((e) => e.label).toList(),
            ),
          ),
        if (stats.weeklyVolume.isNotEmpty)
          const SizedBox(height: 16),

        // Pace evolution chart
        if (stats.paceEvolution.isNotEmpty)
          ChartPanel(
            title: 'EVOLUÇÃO DO PACE',
            subtitle: 'Pace médio por corrida — tendência de desempenho',
            height: 140,
            child: _PaceEvolutionChart(data: stats.paceEvolution),
          ),
        if (stats.paceEvolution.isNotEmpty)
          const SizedBox(height: 16),

        // BPM trend chart
        if (stats.hasBpmTrend)
          ChartPanel(
            title: 'TENDÊNCIA DE BPM',
            subtitle: 'Frequência cardíaca média ao longo das corridas',
            height: 140,
            child: _BpmTrendChart(data: stats.bpmTrend),
          ),
        if (stats.hasBpmTrend)
          const SizedBox(height: 16),

        // Evolution summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.runninPalette.surface,
            border: Border.all(color: context.runninPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RESUMO DA EVOLUÇÃO', style: context.runninType.labelCaps),
              const SizedBox(height: 8),
              Text(stats.evolutionSummary, style: context.runninType.bodyMd.copyWith(height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Coach analysis
        CoachNarrativeCard(
          text: _buildCoachNarrative(stats),
          borderColor: context.runninPalette.secondary,
        ),
      ],
    );
  }

  static _HistoryStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _HistoryStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));

    // Pace médio
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

    // Volume semanal
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

    // Streak
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

    // Pace evolution (last 10 runs)
    final paceEvolution = runsWithPace.take(10).toList().reversed.map((r) {
      final d = DateTime.tryParse(r.createdAt);
      final dateLabel = d != null ? DateFormat('dd/MM').format(d) : '';
      return _PacePoint(label: dateLabel, pace: r.avgPace!);
    }).toList();

    // BPM trend
    final runsWithBpm = runs.where((r) => r.avgBpm != null).take(10).toList().reversed.map((r) {
      final d = DateTime.tryParse(r.createdAt);
      final dateLabel = d != null ? DateFormat('dd/MM').format(d) : '';
      return _BpmPoint(label: dateLabel, bpm: r.avgBpm!);
    }).toList();

    // HR zones (simulated from BPM data)
    final hrZones = _computeHrZones(runs);

    // Evolution summary
    String evolutionSummary = _buildEvolutionSummary(runs, runsWithPace, weeklyVolume);

    return _HistoryStats(
      count: runs.length,
      totalKm: totalDistM / 1000,
      totalTimeLabel: totalTimeLabel,
      avgPaceLabel: avgPaceLabel,
      streakDays: streak,
      totalXp: totalXp,
      weeklyVolume: weeklyVolume,
      hrZones: hrZones,
      paceEvolution: paceEvolution,
      bpmTrend: runsWithBpm,
      evolutionSummary: evolutionSummary,
    );
  }

  static List<_HrZone> _computeHrZones(List<Run> runs) {
    final withBpm = runs.where((r) => r.avgBpm != null).toList();
    if (withBpm.isEmpty) return [];

    int z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0;
    for (final r in withBpm) {
      final bpm = r.avgBpm!;
      if (bpm < 120) z1++;
      else if (bpm < 140) z2++;
      else if (bpm < 160) z3++;
      else if (bpm < 180) z4++;
      else z5++;
    }
    final total = (z1 + z2 + z3 + z4 + z5);
    if (total == 0) return [];

    return [
      _HrZone(label: 'Z1', pct: (z1 / total * 100).round(), color: const Color(0xFF4CAF50)),
      _HrZone(label: 'Z2', pct: (z2 / total * 100).round(), color: const Color(0xFF8BC34A)),
      _HrZone(label: 'Z3', pct: (z3 / total * 100).round(), color: const Color(0xFFFFC107)),
      _HrZone(label: 'Z4', pct: (z4 / total * 100).round(), color: const Color(0xFFFF9800)),
      _HrZone(label: 'Z5', pct: (z5 / total * 100).round(), color: const Color(0xFFF44336)),
    ];
  }

  static String _buildEvolutionSummary(List<Run> runs, List<Run> runsWithPace, List<_WeeklyEntry> weeklyVolume) {
    if (runs.length < 2) {
      return 'Continue correndo para gerar insights de evolução. Quanto mais dados, melhor a análise.';
    }
    final parts = <String>[];
    if (runsWithPace.length >= 2) {
      parts.add('Seu pace médio se mantém consistente ao longo das últimas corridas.');
    }
    if (weeklyVolume.length >= 2) {
      final first = weeklyVolume.first.km;
      final last = weeklyVolume.last.km;
      if (last > first) {
        parts.add('O volume semanal apresentou crescimento, indicando progressão de carga.');
      } else if (last < first) {
        parts.add('O volume semanal reduziu — talvez um período de recuperação ou descanso.');
      }
    }
    if (runs.length >= 5) {
      parts.add('Você completou ${runs.length} corridas no período, mantendo uma boa frequência de treinos.');
    }
    return parts.isEmpty
        ? 'Continue correndo para gerar insights de evolução.'
        : parts.join(' ');
  }

  static String _buildCoachNarrative(_HistoryStats s) {
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
  final List<_HrZone> hrZones;
  final List<_PacePoint> paceEvolution;
  final List<_BpmPoint> bpmTrend;
  final String evolutionSummary;

  const _HistoryStats({
    required this.count,
    required this.totalKm,
    required this.totalTimeLabel,
    required this.avgPaceLabel,
    required this.streakDays,
    required this.totalXp,
    required this.weeklyVolume,
    required this.hrZones,
    required this.paceEvolution,
    required this.bpmTrend,
    required this.evolutionSummary,
  });

  bool get hasHeartRateData => hrZones.isNotEmpty;
  bool get hasBpmTrend => bpmTrend.isNotEmpty;

  factory _HistoryStats.empty() => const _HistoryStats(
    count: 0, totalKm: 0, totalTimeLabel: '0m',
    avgPaceLabel: '--:--', streakDays: 0, totalXp: 0, weeklyVolume: [],
    hrZones: [], paceEvolution: [], bpmTrend: [],
    evolutionSummary: '',
  );
}

class _WeeklyEntry {
  final String label;
  final double km;
  const _WeeklyEntry({required this.label, required this.km});
}

class _HrZone {
  final String label;
  final int pct;
  final Color color;
  const _HrZone({required this.label, required this.pct, required this.color});
}

class _PacePoint {
  final String label;
  final String pace;
  const _PacePoint({required this.label, required this.pace});
}

class _BpmPoint {
  final String label;
  final int bpm;
  const _BpmPoint({required this.label, required this.bpm});
}

// ── HR Zones Bar ──────────────────────────────────────────────────────────

class _HrZonesChart extends StatelessWidget {
  final List<_HrZone> zones;
  const _HrZonesChart({required this.zones});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Row(
      children: zones.map((z) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: z.color.withValues(alpha: 0.25),
                  border: Border.all(color: z.color.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: z.pct / 100.0,
                  child: Container(color: z.color),
                ),
              ),
              const SizedBox(height: 6),
              Text(z.label, style: type.labelCaps),
              Text('${z.pct}%', style: type.labelCaps.copyWith(fontSize: 10)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ── Pace Evolution Chart ──────────────────────────────────────────────────

class _PaceEvolutionChart extends StatelessWidget {
  final List<_PacePoint> data;
  const _PaceEvolutionChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    if (data.isEmpty) return const SizedBox.shrink();

    final paces = data.map((p) {
      final parts = p.pace.split(':');
      if (parts.length != 2) return 300.0;
      return (int.tryParse(parts[0]) ?? 5) * 60 + (int.tryParse(parts[1]) ?? 0).toDouble();
    }).toList();

    final minPace = paces.reduce((a, b) => a < b ? a : b);
    final maxPace = paces.reduce((a, b) => a > b ? a : b);
    final range = (maxPace - minPace).clamp(1.0, double.infinity);

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              values: paces.map((p) => (p - minPace) / range).toList(),
              color: palette.primary,
              dotColor: palette.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(data.length, (i) => Expanded(
            child: Text(
              data[i].label,
              textAlign: TextAlign.center,
              style: type.labelCaps.copyWith(fontSize: 8),
            ),
          )),
        ),
      ],
    );
  }
}

// ── BPM Trend Chart ───────────────────────────────────────────────────────

class _BpmTrendChart extends StatelessWidget {
  final List<_BpmPoint> data;
  const _BpmTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    if (data.isEmpty) return const SizedBox.shrink();

    final maxBpm = data.map((p) => p.bpm).reduce((a, b) => a > b ? a : b);
    final minBpm = data.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
    final range = (maxBpm - minBpm).clamp(1, double.infinity).toDouble();

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              values: data.map((p) => (p.bpm - minBpm) / range).toList(),
              color: palette.secondary,
              dotColor: palette.secondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(data.length, (i) => Expanded(
            child: Text(
              data[i].label,
              textAlign: TextAlign.center,
              style: type.labelCaps.copyWith(fontSize: 8),
            ),
          )),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color dotColor;

  _LineChartPainter({required this.values, required this.color, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final w = size.width / (values.length - 1).clamp(1, values.length);
    final h = size.height - 8;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * w + w / 2;
      final y = h - (values[i] * h).clamp(2.0, h - 2.0);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.values != values;
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
      onTap: () => context.push('/run-detail', extra: run.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            // Date
            SizedBox(
              width: 36,
              child: Text(
                date.replaceAll(' ', '\n'),
                textAlign: TextAlign.center,
                style: type.labelCaps.copyWith(height: 1.3),
              ),
            ),
            const SizedBox(width: 12),
            // Type + FREE badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: palette.primary.withValues(alpha: 0.15),
                  child: Text(
                    run.type.toUpperCase(),
                    style: type.labelCaps.copyWith(color: palette.primary),
                  ),
                ),
                const SizedBox(height: 4),
                AppTag(label: 'FREE', color: palette.muted),
              ],
            ),
            const SizedBox(width: 12),
            // Metrics
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
    try { return DateFormat('dd/MM').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return iso.substring(0, 10); }
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
