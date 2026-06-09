import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/biometrics/domain/recovery_score.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_hist_stat_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthTrendsPage extends StatefulWidget {
  const HealthTrendsPage({super.key});

  @override
  State<HealthTrendsPage> createState() => _HealthTrendsPageState();
}

class _HealthTrendsPageState extends State<HealthTrendsPage> with WidgetsBindingObserver {
  final _remoteRuns = RunRemoteDatasource();
  final _remoteUser = UserRemoteDatasource();
  final _remoteBiometrics = BiometricRemoteDatasource();
  List<Run>? _runs;
  UserProfile? _userProfile;
  BiometricSummary? _biometricSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1) Dispara sync HK em paralelo (best-effort, sem bloquear load inicial).
    // 2) Carrega o que já tem no server. 3) Quando sync termina, recarrega.
    _refreshHealthAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshHealthAndLoad();
    }
  }

  /// Puxa samples novos do HK pro server e em seguida refaz a query da
  /// summary. Sem isso, abrir Tendências de manhã mostrava sono da noite
  /// anterior porque o sample do Watch ainda não tinha sido enviado.
  Future<void> _refreshHealthAndLoad() async {
    try {
      await healthSyncService.syncSince();
    } catch (_) {/* best-effort */}
    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _remoteRuns.listRuns(limit: 90),
        _remoteUser.getMe(),
        _remoteBiometrics.getSummary(windowDays: 7),
      ]);
      if (mounted) {
        setState(() {
          _runs = (results[0] as List<Run>).where((r) => r.status == 'completed').toList();
          _userProfile = results[1] as UserProfile;
          _biometricSummary = results[2] as BiometricSummary;
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
              breadcrumb: 'TENDÊNCIAS',
              showBackButton: true,
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.runninPalette.primary,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _Body(
                      runs: _runs ?? [],
                      userProfile: _userProfile,
                      biometricSummary: _biometricSummary,
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

/// Computa o recovery a partir do summary biométrico + perfil. Antes
/// dependia só de HRV (sempre null sem wearable HRV-capable). Agora
/// combina sono + BPM resting + HRV, com pesos que redistribuem quando
/// um sinal falta — ver [computeRecoveryScore].
///
/// restingBpm prioriza o valor do perfil (declarado pelo user) e cai
/// pro biometrics summary; sleep e hrv só vêm do summary.
RecoveryScore _recoveryFromSources(
  UserProfile? profile,
  BiometricSummary? summary,
) {
  final resting = profile?.restingBpm ?? summary?.avgRestingBpm;
  return computeRecoveryScore(
    avgSleepHours: summary?.avgSleepHours,
    avgRestingBpm: resting,
    avgHrv: summary?.avgHrv,
  );
}

/// Label sutil pro card de recovery: lista os sinais que entraram no
/// cálculo ("sono · bpm" ou "sono · bpm · hrv"). Usado quando o score
/// existe — quando falta sinal, a UI mostra um CTA em vez deste label.
String? _recoveryComponentsLabel(RecoveryComponents c) {
  final parts = <String>[];
  if (c.sleepUsed) parts.add('sono');
  if (c.restingBpmUsed) parts.add('bpm');
  if (c.hrvUsed) parts.add('hrv');
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

class _Body extends StatelessWidget {
  const _Body({required this.runs, required this.userProfile, required this.biometricSummary});
  final List<Run> runs;
  final UserProfile? userProfile;
  final BiometricSummary? biometricSummary;

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats(runs);
    final sleepHours = biometricSummary?.avgSleepHours;
    final recovery = _recoveryFromSources(userProfile, biometricSummary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(23.99),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionHeader(label: 'TENDÊNCIAS'),
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
                valueColor: context.runninPalette.primary,
              ),
              _HealthCard(
                label: 'BPM corrida',
                value: stats.avgBpm > 0 ? stats.avgBpm.toString() : '—',
                unit: 'bpm',
                valueColor: context.runninPalette.primary,
              ),
              _HealthCard(
                label: 'Sono médio',
                // Formato h:mm (mesma representação do Apple Health).
                value: sleepHours != null
                    ? _hoursToHhMm(sleepHours)
                    : '—',
                unit: '',
                // Mostra qualidade quando há stages registradas (Apple Watch
                // iOS 16+ writes sleep_deep + rem + light). Sem stages,
                // mostra só "Média 7 dias" ou "Sem dados".
                secondaryLabel: sleepHours != null
                    ? biometricSummary?.avgSleepQualityScore != null
                        ? 'Qualidade ${biometricSummary!.avgSleepQualityScore!.toInt()}/100'
                        : 'Média 7 dias'
                    : 'Sem dados',
                valueColor: FigmaColors.brandGreen,
              ),
              _HealthCard(
                label: 'Recovery score',
                value: recovery.score?.toString() ?? '—',
                unit: recovery.hasScore ? '/100' : '',
                secondaryLabel: recovery.hasScore
                    ? _recoveryComponentsLabel(recovery.components)
                    : 'Conecte sono e BPM repouso',
                valueColor: context.runninPalette.secondary,
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
    this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final String? secondaryLabel;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return FigmaHistStatCard(
      label: label,
      value: value,
      unit: unit,
      delta: null,
      deltaIsPositive: true,
      valueColor: valueColor ?? context.runninPalette.primary,
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
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.runninType.dataXs.copyWith(
        color: FigmaColors.textPrimary,
        height: 24.2 / 22,
      ),
    );
  }
}

/// Converte horas decimais pra formato "h:mm" (ex: 5.3h → "5:18").
/// Espelha o que Apple Health mostra. Duplicado do home_page.dart porque
/// não vale o overhead de criar um util compartilhado pra uma função
/// de 4 linhas; quando virar 3 lugares, refatorar.
String _hoursToHhMm(num hours) {
  final totalMin = (hours * 60).round();
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}
