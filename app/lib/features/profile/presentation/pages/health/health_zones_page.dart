import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/biometrics/domain/run_zones.dart';
import 'package:runnin/features/profile/presentation/pages/health/zones_utils.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_card.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_distribution_bar.dart';

/// Janela de runs considerada pra computar a distribuição. 30d cobre a
/// maioria das corridas de um user ativo sem trazer ruído de meses atrás.
const int _kWindowDays = 30;

/// Mostra as 5 zonas cardíacas do user com (a) ranges Karvonen calculados
/// pela cascata profile → derived → fallback genérico (60/190) e (b) a
/// distribuição real de tempo nas zonas das últimas 30d de corridas.
///
/// Antes a página mostrava banner "Sem dados carregados" sempre que faltava
/// profile.restingBpm/maxBpm. User reclamou — agora cai em ranges genéricos
/// + badge "GENÉRICO" pra ser transparente sobre a origem dos números.
class HealthZonesPage extends StatefulWidget {
  const HealthZonesPage({super.key});

  @override
  State<HealthZonesPage> createState() => _HealthZonesPageState();
}

class _HealthZonesPageState extends State<HealthZonesPage> {
  final _userDatasource = UserRemoteDatasource();
  final _biometricDatasource = BiometricRemoteDatasource();
  final _runDatasource = RunRemoteDatasource();

  List<HealthZone> _zones = [];
  int? _effectiveMax;
  BpmRangeSource _bpmSource = BpmRangeSource.profile;
  bool _hasDistribution = false;
  int? _observedMaxFromRuns;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    UserProfile? profile;
    BiometricSummary? summary;
    var runs = const <dynamic>[];

    // Best-effort em paralelo — qualquer falha vira null/[] e a UI ainda
    // renderiza com os defaults genéricos.
    try {
      profile = await _userDatasource.getMe();
    } catch (_) {}
    try {
      summary = await _biometricDatasource.getSummary(windowDays: _kWindowDays);
    } catch (_) {}
    try {
      // listRuns sem limit explícito traz 20 (default datasource). É o
      // que o histórico usa — manter coerente.
      final fetched = await _runDatasource.listRuns(limit: 40);
      final cutoff = DateTime.now().subtract(const Duration(days: _kWindowDays));
      runs = fetched.where((r) {
        final d = DateTime.tryParse(r.createdAt);
        return d != null && d.isAfter(cutoff);
      }).toList();
    } catch (_) {}

    if (!mounted) return;

    final range = resolveBpmRange(profile: profile, summary: summary);
    final dist = computeAggregateRunZoneDistribution(
      runs: List.from(runs),
      profile: profile,
      summary: summary,
    );

    // Quando temos distribuição real, usa zones com pctTime preenchido.
    // Senão, ainda mostra os 5 cards com ranges (pctTime=0) — melhor que
    // tela vazia.
    final zones = dist.zones.isNotEmpty
        ? dist.zones
        : computeHealthZones(restingBpm: range.resting, maxBpm: range.max);

    setState(() {
      _effectiveMax = range.max;
      _bpmSource = range.source;
      _zones = zones;
      _hasDistribution = dist.hasEnoughBpmData;
      _observedMaxFromRuns = dist.maxBpmRun;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            FigmaTopNav(
              breadcrumb: 'ZONAS',
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
                      maxBpm: _effectiveMax!,
                      zones: _zones,
                      source: _bpmSource,
                      hasDistribution: _hasDistribution,
                      observedMaxFromRuns: _observedMaxFromRuns,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.maxBpm,
    required this.zones,
    required this.source,
    required this.hasDistribution,
    required this.observedMaxFromRuns,
  });

  final int maxBpm;
  final List<HealthZone> zones;
  final BpmRangeSource source;
  final bool hasDistribution;
  final int? observedMaxFromRuns;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(23.99),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionHeader(label: 'SAÚDE'),
          const SizedBox(height: 4),
          Text(
            'Distribuição de frequência cardíaca',
            style: context.runninType.bodyMd.copyWith(
              fontSize: 13,
              color: FigmaColors.textMuted,
              height: 19.5 / 13,
            ),
          ),
          const SizedBox(height: 24),
          _MaxBpmHeader(
            maxBpm: maxBpm,
            source: source,
            observedMaxFromRuns: observedMaxFromRuns,
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'ZONAS'),
          const SizedBox(height: 16),
          // Distribuição visual — só faz sentido quando temos pelo menos
          // uma run com BPM nas últimas 30d.
          if (hasDistribution) ...[
            FigmaZoneDistributionBar(
              zonePercentages: zones.map((z) => z.pctTime).toList(),
            ),
            const SizedBox(height: 16),
          ],
          for (final zone in zones)
            FigmaZoneCard(
              zoneNumber: zone.number,
              zoneLabel: zone.label,
              bpmRange: '${zone.minBpm}-${zone.maxBpm}',
              percent: zone.pctTime,
              zoneColor: zone.color,
            ),
          if (!hasDistribution) ...[
            const SizedBox(height: 12),
            Text(
              'Sem dados de BPM nas últimas $_kWindowDays dias — corra com um sensor pra ver sua distribuição real.',
              style: context.runninType.bodySm.copyWith(
                color: FigmaColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(label: 'SOBRE AS ZONAS'),
          const SizedBox(height: 16),
          for (final zone in zones)...[
            _ZoneDescription(zone: zone),
            if (zone != zones.last) const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MaxBpmHeader extends StatelessWidget {
  const _MaxBpmHeader({
    required this.maxBpm,
    required this.source,
    required this.observedMaxFromRuns,
  });
  final int maxBpm;
  final BpmRangeSource source;
  final int? observedMaxFromRuns;

  String? get _sourceBadge {
    switch (source) {
      case BpmRangeSource.profile:
        return null;
      case BpmRangeSource.derived:
        return 'ESTIMADO';
      case BpmRangeSource.genericFallback:
        return 'GENÉRICO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _sourceBadge;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FC MÁX',
                    style: context.runninType.labelMd.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      badge,
                      style: context.runninType.labelCaps.copyWith(
                        fontSize: 9,
                        color: context.runninPalette.primary,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '$maxBpm bpm',
                style: context.runninType.dataXs.copyWith(
                  fontSize: 24,
                  letterSpacing: 0,
                  color: FigmaColors.textPrimary,
                ),
              ),
            ],
          ),
          // Quando temos um pico observado nas runs maior que o max teórico,
          // expõe pro user — sinal de que o range tá subestimado e pode
          // precisar atualizar o profile.
          if (observedMaxFromRuns != null && observedMaxFromRuns! > maxBpm) ...[
            const SizedBox(height: 12),
            Text(
              'Pico observado nas corridas: ${observedMaxFromRuns!} bpm',
              style: context.runninType.bodySm.copyWith(
                color: FigmaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneDescription extends StatelessWidget {
  const _ZoneDescription({required this.zone});
  final HealthZone zone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                color: zone.color,
                child: Text(
                  'Z${zone.number}',
                  style: context.runninType.labelCaps.copyWith(
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.bgBase,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                zone.label,
                style: context.runninType.bodyMd.copyWith(
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            zone.description,
            style: context.runninType.bodySm.copyWith(
              color: FigmaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
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
