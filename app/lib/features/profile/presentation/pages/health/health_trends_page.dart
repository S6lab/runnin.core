import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
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
  final _remoteRuns = RunRemoteDatasource();
  final _remoteUser = UserRemoteDatasource();
  List<Run>? _runs;
  UserProfile? _userProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await _remoteRuns.listRuns(limit: 90);
      final userProfile = await _remoteUser.getMe();
      
      if (mounted) {
        setState(() {
          _runs = runs.where((r) => r.status == 'completed').toList();
          _userProfile = userProfile;
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
                  : _Body(
                      runs: _runs ?? [],
                      userProfile: _userProfile,
                    ),
            ),
          ],
        ),
      ),
    );
  }

}

_Stats _buildStats(List<Run> runs) {
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

    final hasRunData = recent7.isNotEmpty;

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
      hasRunData: hasRunData,
      runCount: recent7.length,
    );
}

class _Body extends StatelessWidget {
  const _Body({required this.runs, required this.userProfile});
  final List<Run> runs;
  final UserProfile? userProfile;

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats(runs);

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
              _HealthCard(
                label: 'BPM repouso',
                value: userProfile?.restingBpm?.toString() ?? '—',
                unit: 'bpm',
                valueColor: FigmaColors.brandCyan,
              ),
              _HealthCard(
                label: 'BPM corrida',
                value: stats.avgBpm > 0 ? stats.avgBpm.toString() : '—',
                unit: 'bpm',
                valueColor: FigmaColors.brandCyan,
              ),
              _HealthCard(
                label: 'Pace médio',
                value: stats.avgPace.isNotEmpty ? stats.avgPace : '—',
                unit: '/km',
                valueColor: FigmaColors.brandOrange,
              ),
              _HealthCard(
                label: 'Dist. semanal',
                value: stats.weeklyDistKm > 0
                    ? stats.weeklyDistKm.toStringAsFixed(1)
                    : '—',
                unit: 'km',
                valueColor: FigmaColors.brandOrange,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.label,
    required this.value,
    required this.unit,
    this.secondaryLabel,
    this.valueColor = FigmaColors.brandCyan,
  });

  final String label;
  final String value;
  final String unit;
  final String? secondaryLabel;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return FigmaHistStatCard(
      label: label,
      value: value,
      unit: unit,
      delta: null,
      deltaIsPositive: true,
      valueColor: valueColor,
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
    required this.hasRunData,
    required this.runCount,
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
  final bool hasRunData;
  final int runCount;

  bool get hasBpmData => avgBpm > 0;
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
