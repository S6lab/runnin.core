import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/profile/presentation/pages/health/zones_utils.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

/// Origem do par (restingBpm, maxBpm) que alimenta as zonas. Usado pra
/// exibir o badge "ESTIMADO" quando o usuário ainda não configurou os
/// valores no perfil (cai pra biometrics summary + 220-idade).
enum _BpmSource { profile, derived }

class HealthZonesPage extends StatefulWidget {
  const HealthZonesPage({super.key});

  @override
  State<HealthZonesPage> createState() => _HealthZonesPageState();
}

class _HealthZonesPageState extends State<HealthZonesPage> {
  final _userDatasource = UserRemoteDatasource();
  final _biometricDatasource = BiometricRemoteDatasource();
  List<HealthZone> _zones = [];
  int? _effectiveMax;
  _BpmSource _bpmSource = _BpmSource.profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileAndZones();
  }

  Future<void> _loadProfileAndZones() async {
    try {
      final profile = await _userDatasource.getMe();
      if (!mounted) return;

      // Cascade pros valores efetivos:
      //   restingBpm: profile → biometrics.avgRestingBpm
      //   maxBpm:     profile → (220 - idade)  → biometrics.maxBpm observado
      int? resting = profile?.restingBpm;
      int? max = profile?.maxBpm;
      var source = _BpmSource.profile;

      if (resting == null || max == null) {
        source = _BpmSource.derived;
        // Try birthDate → idade → 220 - idade.
        if (max == null) {
          final age = _ageFromBirthDate(profile?.birthDate);
          if (age != null && age > 0 && age < 120) {
            max = 220 - age;
          }
        }
        // Biometrics summary (30 dias) cobre o gap quando os outros falham.
        try {
          final summary = await _biometricDatasource.getSummary(windowDays: 30);
          if (!mounted) return;
          resting ??= summary.avgRestingBpm?.round();
          max ??= summary.maxBpm?.round();
        } catch (_) {
          // best-effort: sem summary, exibe banner se ainda faltar valor.
        }
      }

      final zones = (resting != null && max != null && max > resting)
          ? computeHealthZones(restingBpm: resting, maxBpm: max)
          : <HealthZone>[];

      setState(() {
        _effectiveMax = max;
        _bpmSource = source;
        _zones = zones;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Aceita ISO yyyy-MM-dd ou dd/MM/yyyy. Devolve idade em anos completos.
  static int? _ageFromBirthDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    DateTime? d;
    try {
      d = DateTime.parse(raw);
    } catch (_) {
      final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
      if (br != null) {
        d = DateTime(
          int.parse(br.group(3)!),
          int.parse(br.group(2)!),
          int.parse(br.group(1)!),
        );
      }
    }
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age -= 1;
    }
    return age;
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
                  : _zones.isEmpty
                      ? const _MissingBpmBanner()
                      : _Body(
                          maxBpm: _effectiveMax!,
                          zones: _zones,
                          estimated: _bpmSource == _BpmSource.derived,
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
    required this.estimated,
  });

  final int maxBpm;
  final List<HealthZone> zones;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(23.99),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionHeader(label: 'SAÚDE', index: '01'),
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
          _MaxBpmHeader(maxBpm: maxBpm, estimated: estimated),
          const SizedBox(height: 24),
          _SectionHeader(label: 'ZONAS', index: '02'),
          const SizedBox(height: 16),
          for (final zone in zones)
            FigmaZoneCard(
              zoneNumber: zone.number,
              zoneLabel: zone.label,
              bpmRange: '${zone.minBpm}-${zone.maxBpm}',
              percent: zone.pctTime,
              zoneColor: zone.color,
            ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'SOBRE AS ZONAS', index: '03'),
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

class _MissingBpmBanner extends StatelessWidget {
  const _MissingBpmBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DADOS INCOMPLETOS',
            style: context.runninType.dataXs.copyWith(
              color: FigmaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Preencha sua data de nascimento ou sua frequência cardíaca em repouso e máxima no perfil para visualizar suas zonas.',
            textAlign: TextAlign.center,
            style: context.runninType.bodySm.copyWith(
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.runninPalette.primary, width: 1),
              ),
              child: Text(
                'PREENCHER PERFIL',
                style: context.runninType.labelCaps.copyWith(
                  color: context.runninPalette.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaxBpmHeader extends StatelessWidget {
  const _MaxBpmHeader({required this.maxBpm, required this.estimated});
  final int maxBpm;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
      ),
      child: Row(
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
              if (estimated) ...[
                const SizedBox(height: 4),
                Text(
                  'ESTIMADO',
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
            style: context.runninType.dataXs.copyWith(
              color: FigmaColors.textPrimary,
              height: 24.2 / 22,
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Text(
              index,
              style: context.runninType.labelCaps.copyWith(
                fontSize: 6.6,
                fontWeight: FontWeight.w400,
                color: context.runninPalette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
