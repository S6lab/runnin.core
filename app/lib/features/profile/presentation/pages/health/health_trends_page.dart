import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_chart_line_spark.dart';
import 'package:runnin/shared/widgets/figma/figma_hist_stat_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthTrendsPage extends StatefulWidget {
  const HealthTrendsPage({super.key});

  @override
  State<HealthTrendsPage> createState() => _HealthTrendsPageState();
}

class _HealthTrendsPageState extends State<HealthTrendsPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _runs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await _remote.listRuns(limit: 90);
      if (mounted) {
        setState(() {
          _runs = runs.where((r) => r.status == 'completed').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            FigmaTopNav(
              breadcrumb: 'Perfil / Saúde / Tendências',
              showBackButton: true,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FigmaColors.brandCyan,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _Body(runs: _runs ?? []),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.runs});
  final List<Run> runs;

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(23.99),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionHeader(label: 'TENDÊNCIAS', index: '01'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 7.997,
            mainAxisSpacing: 7.997,
            childAspectRatio: 1.35,
            children: [
              FigmaHistStatCard(
                label: 'BPM MÉDIO',
                value: stats.avgBpm > 0 ? stats.avgBpm.toString() : '—',
                unit: 'bpm',
                delta: stats.bpmDelta,
                deltaIsPositive: stats.bpmDeltaPositive,
                valueColor: FigmaColors.brandCyan,
              ),
              FigmaHistStatCard(
                label: 'PACE MÉDIO',
                value: stats.avgPace.isNotEmpty ? stats.avgPace : '—',
                unit: '/km',
                delta: stats.paceDelta,
                deltaIsPositive: stats.paceDeltaPositive,
                valueColor: FigmaColors.brandCyan,
              ),
              FigmaHistStatCard(
                label: 'DIST. SEMANAL',
                value: stats.weeklyDistKm > 0
                    ? stats.weeklyDistKm.toStringAsFixed(1)
                    : '—',
                unit: 'km',
                delta: stats.distDelta,
                deltaIsPositive: stats.distDeltaPositive,
                valueColor: FigmaColors.brandOrange,
              ),
              FigmaHistStatCard(
                label: 'TEMPO TOTAL',
                value: stats.totalTimeLabel.isNotEmpty
                    ? stats.totalTimeLabel
                    : '—',
                delta: stats.timeDelta,
                deltaIsPositive: stats.timeDeltaPositive,
                valueColor: FigmaColors.brandOrange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'BPM — 30 DIAS', index: '02'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: FigmaColors.surfaceCard,
              border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stats.bpmSeries.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Dados insuficientes',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  FigmaChartLineSpark(
                    values: stats.bpmSeries,
                    height: 100,
                    lineColor: FigmaColors.brandCyan,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stats.bpmSeriesStart,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                    Text(
                      stats.bpmSeriesEnd,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  _Stats _computeStats(List<Run> runs) {
    final now = DateTime.now();
    final cutoff30 = now.subtract(const Duration(days: 30));
    final cutoff7 = now.subtract(const Duration(days: 7));
    final cutoffPrev7 = now.subtract(const Duration(days: 14));

    final recent30 = runs.where((r) {
      try {
        return DateTime.parse(r.createdAt).isAfter(cutoff30);
      } catch (_) {
        return false;
      }
    }).toList();

    final recent7 = runs.where((r) {
      try {
        return DateTime.parse(r.createdAt).isAfter(cutoff7);
      } catch (_) {
        return false;
      }
    }).toList();

    final prev7 = runs.where((r) {
      try {
        final d = DateTime.parse(r.createdAt);
        return d.isAfter(cutoffPrev7) && d.isBefore(cutoff7);
      } catch (_) {
        return false;
      }
    }).toList();

    // BPM
    final bpmRuns = recent30.where((r) => r.avgBpm != null).toList();
    final avgBpm = bpmRuns.isEmpty
        ? 0
        : (bpmRuns.map((r) => r.avgBpm!).reduce((a, b) => a + b) /
                bpmRuns.length)
            .round();

    final prevBpmRuns = prev7.where((r) => r.avgBpm != null).toList();
    final prevAvgBpm = prevBpmRuns.isEmpty
        ? 0
        : (prevBpmRuns.map((r) => r.avgBpm!).reduce((a, b) => a + b) /
                prevBpmRuns.length)
            .round();
    final bpmDiff = avgBpm - prevAvgBpm;
    final String? bpmDelta = bpmRuns.isNotEmpty && prevBpmRuns.isNotEmpty
        ? '${bpmDiff.abs()} bpm (mês)'
        : null;
    final bool bpmDeltaPositive = bpmDiff <= 0;

    // Pace (parse "MM:SS" strings, use seconds for math)
    int paceToSeconds(String? p) {
      if (p == null || p.isEmpty) return 0;
      final parts = p.split(':');
      if (parts.length != 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    }

    String secondsToPace(int s) {
      if (s <= 0) return '';
      final m = s ~/ 60;
      final sec = s % 60;
      return '$m:${sec.toString().padLeft(2, '0')}';
    }

    final paceRuns = recent7.where((r) => r.avgPace != null).toList();
    final avgPaceSec = paceRuns.isEmpty
        ? 0
        : (paceRuns.map((r) => paceToSeconds(r.avgPace)).reduce((a, b) => a + b) /
                paceRuns.length)
            .round();

    final prevPaceRuns = prev7.where((r) => r.avgPace != null).toList();
    final prevPaceSec = prevPaceRuns.isEmpty
        ? 0
        : (prevPaceRuns
                    .map((r) => paceToSeconds(r.avgPace))
                    .reduce((a, b) => a + b) /
                prevPaceRuns.length)
            .round();
    final paceDiffSec = avgPaceSec - prevPaceSec;
    final String? paceDelta = paceRuns.isNotEmpty && prevPaceRuns.isNotEmpty
        ? '${secondsToPace(paceDiffSec.abs())} /km'
        : null;
    final bool paceDeltaPositive = paceDiffSec <= 0;

    // Weekly distance
    final weekDistM = recent7.fold<double>(0, (s, r) => s + r.distanceM);
    final weekDistKm = weekDistM / 1000;
    final prevDistM = prev7.fold<double>(0, (s, r) => s + r.distanceM);
    final prevDistKm = prevDistM / 1000;
    final distDiff = weekDistKm - prevDistKm;
    final String? distDelta = recent7.isNotEmpty && prev7.isNotEmpty
        ? '${distDiff.abs().toStringAsFixed(1)} km'
        : null;

    // Total time (last 30 days)
    final totalSecs = recent30.fold<int>(0, (s, r) => s + r.durationS);
    final totalH = totalSecs ~/ 3600;
    final totalM = (totalSecs % 3600) ~/ 60;
    final totalTimeLabel = totalH > 0 ? '${totalH}h${totalM}m' : '${totalM}m';
    final prevTotalSecs = prev7.fold<int>(0, (s, r) => s + r.durationS);
    final timeDiffSec = totalSecs - prevTotalSecs;
    final timeDiffM = timeDiffSec.abs() ~/ 60;
    final String? timeDelta = recent30.isNotEmpty && prev7.isNotEmpty
        ? '${timeDiffM}m'
        : null;

    // BPM spark series (last 30 days, chronological)
    final bpmSeriesRuns = recent30.where((r) => r.avgBpm != null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final bpmSeries = bpmSeriesRuns.map((r) => r.avgBpm!.toDouble()).toList();

    String bpmSeriesStart = '';
    String bpmSeriesEnd = '';
    if (bpmSeriesRuns.isNotEmpty) {
      try {
        final first = DateTime.parse(bpmSeriesRuns.first.createdAt);
        final last = DateTime.parse(bpmSeriesRuns.last.createdAt);
        bpmSeriesStart =
            '${first.day.toString().padLeft(2, '0')}/${first.month.toString().padLeft(2, '0')}';
        bpmSeriesEnd =
            '${last.day.toString().padLeft(2, '0')}/${last.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return _Stats(
      avgBpm: avgBpm,
      bpmDelta: bpmDelta,
      bpmDeltaPositive: bpmDeltaPositive,
      avgPace: secondsToPace(avgPaceSec),
      paceDelta: paceDelta,
      paceDeltaPositive: paceDeltaPositive,
      weeklyDistKm: weekDistKm,
      distDelta: distDelta,
      distDeltaPositive: distDiff >= 0,
      totalTimeLabel: totalTimeLabel,
      timeDelta: timeDelta,
      timeDeltaPositive: timeDiffSec >= 0,
      bpmSeries: bpmSeries,
      bpmSeriesStart: bpmSeriesStart,
      bpmSeriesEnd: bpmSeriesEnd,
    );
  }
}

class _Stats {
  const _Stats({
    required this.avgBpm,
    required this.bpmDelta,
    required this.bpmDeltaPositive,
    required this.avgPace,
    required this.paceDelta,
    required this.paceDeltaPositive,
    required this.weeklyDistKm,
    required this.distDelta,
    required this.distDeltaPositive,
    required this.totalTimeLabel,
    required this.timeDelta,
    required this.timeDeltaPositive,
    required this.bpmSeries,
    required this.bpmSeriesStart,
    required this.bpmSeriesEnd,
  });

  final int avgBpm;
  final String? bpmDelta;
  final bool bpmDeltaPositive;
  final String avgPace;
  final String? paceDelta;
  final bool paceDeltaPositive;
  final double weeklyDistKm;
  final String? distDelta;
  final bool distDeltaPositive;
  final String totalTimeLabel;
  final String? timeDelta;
  final bool timeDeltaPositive;
  final List<double> bpmSeries;
  final String bpmSeriesStart;
  final String bpmSeriesEnd;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.index});
  final String label;
  final String index;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.44,
              color: FigmaColors.textPrimary,
              height: 24.2 / 22,
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Text(
              index,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 6.6,
                fontWeight: FontWeight.w400,
                color: FigmaColors.brandCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
