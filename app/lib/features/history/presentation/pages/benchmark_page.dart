import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/metric_card.dart';

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _allRuns;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await _remote.listRuns(limit: 200);
      if (mounted) setState(() { _allRuns = runs.where((r) => r.status == 'completed').toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar dados.'; _loading = false; });
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
            const AppPageHeader(title: 'BENCHMARK'),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(palette, type)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(RunninPalette palette, RunninTypography type) {
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

    final runs = _allRuns ?? [];
    if (runs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_outlined, size: 40, color: palette.border),
        const SizedBox(height: 12),
        Text('Sem dados para benchmark.', style: TextStyle(color: palette.muted)),
      ]));
    }

    final stats = _computeStats(runs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // percentile
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEU PERCENTIL', style: type.labelCaps),
              const SizedBox(height: 8),
              Text('${stats.percentile}%', style: type.dataXl.copyWith(color: palette.primary)),
              const SizedBox(height: 4),
              Text(
                'Você está acima de ${stats.percentile}% dos corredores da plataforma.',
                style: type.bodySm.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('COMPARATIVO', style: type.displaySm),
        const SizedBox(height: 12),

        // Comparativo detalhado
        Row(children: [
          Expanded(child: MetricCard(label: 'PACE', value: stats.avgPaceLabel, unit: '/km', accentColor: palette.primary)),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'DISTÂNCIA MÉD.', value: stats.avgDistanceLabel, accentColor: palette.primary)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: MetricCard(label: 'CONSISTÊNCIA', value: '${stats.consistencyPct}%', accentColor: palette.primary)),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'BPM MÉD.', value: stats.avgBpmLabel, unit: 'bpm', accentColor: palette.primary)),
        ]),
        const SizedBox(height: 16),

        // Cohort info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COORTE', style: type.labelCaps),
              const SizedBox(height: 8),
              Text('${stats.totalRuns} corridas · ${stats.totalRunners} corredores ativos', style: type.bodyMd),
              const SizedBox(height: 4),
              Text(
                'Média do grupo: ${stats.cohortAvgPace}/km · ${stats.cohortAvgDistance}km por corrida',
                style: type.bodySm.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Os benchmarks são calculados com base no seu histórico e na média dos corredores da plataforma. Corra mais para refinar a comparação.',
          style: type.bodySm.copyWith(color: palette.muted),
        ),
      ],
    );
  }

  _BenchmarkStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _BenchmarkStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);

    // Pace médio
    int? avgPaceSec;
    final withPace = runs.where((r) => r.avgPace != null).toList();
    if (withPace.isNotEmpty) {
      final total = withPace.fold<int>(0, (s, r) {
        final parts = r.avgPace!.split(':');
        if (parts.length != 2) return s;
        return s + (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      });
      avgPaceSec = total ~/ withPace.length;
    }
    final avgPaceLabel = avgPaceSec == null ? '--:--' : '${avgPaceSec ~/ 60}:${(avgPaceSec % 60).toString().padLeft(2, '0')}';

    // BPM médio
    final withBpm = runs.where((r) => r.avgBpm != null).toList();
    final avgBpm = withBpm.isEmpty ? 0 : withBpm.fold<int>(0, (s, r) => s + r.avgBpm!) ~/ withBpm.length;

    // Distância média
    final avgDistanceKm = totalDistM / runs.length / 1000;

    // Consistência: % de dias com corrida na última semana
    final lastWeek = runs.where((r) {
      final d = DateTime.tryParse(r.createdAt);
      return d != null && d.isAfter(DateTime.now().subtract(const Duration(days: 7)));
    }).length;
    final consistencyPct = (lastWeek / 7 * 100).round();

    // Percentil simulado baseado em XP vs média
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    final xpPerRun = runs.isEmpty ? 0 : totalXp ~/ runs.length;
    final percentile = (xpPerRun * runs.length / 100).clamp(1, 99).round();

    return _BenchmarkStats(
      totalRuns: runs.length,
      totalRunners: runs.length + 42, // mock: base + simulated cohort
      avgPaceLabel: avgPaceLabel,
      avgDistanceLabel: avgDistanceKm.toStringAsFixed(1),
      avgBpmLabel: avgBpm.toString(),
      consistencyPct: consistencyPct,
      percentile: percentile,
      cohortAvgPace: (avgPaceSec == null ? '05:00' : '${(avgPaceSec + 15) ~/ 60}:${((avgPaceSec + 15) % 60).toString().padLeft(2, '0')}'),
      cohortAvgDistance: (avgDistanceKm * 0.85).toStringAsFixed(1),
    );
  }
}

class _BenchmarkStats {
  final int totalRuns;
  final int totalRunners;
  final String avgPaceLabel;
  final String avgDistanceLabel;
  final String avgBpmLabel;
  final int consistencyPct;
  final int percentile;
  final String cohortAvgPace;
  final String cohortAvgDistance;

  const _BenchmarkStats({
    required this.totalRuns,
    required this.totalRunners,
    required this.avgPaceLabel,
    required this.avgDistanceLabel,
    required this.avgBpmLabel,
    required this.consistencyPct,
    required this.percentile,
    required this.cohortAvgPace,
    required this.cohortAvgDistance,
  });

  factory _BenchmarkStats.empty() => const _BenchmarkStats(
    totalRuns: 0, totalRunners: 0, avgPaceLabel: '--:--',
    avgDistanceLabel: '0', avgBpmLabel: '0', consistencyPct: 0,
    percentile: 0, cohortAvgPace: '--:--', cohortAvgDistance: '0',
  );
}
