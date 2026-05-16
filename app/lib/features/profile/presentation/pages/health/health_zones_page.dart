import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/profile/presentation/pages/health/zones_utils.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthZonesPage extends StatefulWidget {
  const HealthZonesPage({super.key});

  @override
  State<HealthZonesPage> createState() => _HealthZonesPageState();
}

class _HealthZonesPageState extends State<HealthZonesPage> {
  final _userDatasource = UserRemoteDatasource();
  UserProfile? _profile;
  List<HealthZone> _zones = [];
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

      setState(() {
        _profile = profile;
        _zones = computeHealthZones(
          restingBpm: profile?.restingBpm ?? 60,
          maxBpm: profile?.maxBpm ?? 180,
        );
        _loading = false;
      });
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
              breadcrumb: 'Perfil / Saúde / Zonas',
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
                  : _Body(profile: _profile!, zones: _zones),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.profile,
    required this.zones,
  });

  final UserProfile profile;
  final List<HealthZone> zones;

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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textMuted,
              height: 19.5 / 13,
            ),
          ),
          const SizedBox(height: 24),
          _MaxBpmHeader(maxBpm: profile.maxBpm ?? 180),
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

class _MaxBpmHeader extends StatelessWidget {
  const _MaxBpmHeader({required this.maxBpm});
  final int maxBpm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FC MÁX',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          Text(
            '$maxBpm bpm',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
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
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.bgBase,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                zone.label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            zone.description,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w400,
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
