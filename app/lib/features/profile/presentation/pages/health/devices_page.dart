import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_device_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthDevicesPage extends StatefulWidget {
  const HealthDevicesPage({super.key});

  @override
  State<HealthDevicesPage> createState() => _HealthDevicesPageState();
}

class _HealthDevicesPageState extends State<HealthDevicesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Saúde / Dispositivos',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'CONECTADOS'),
                  const SizedBox(height: AppSpacing.md),
                  const _EmptyConnectedState(),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'COMPATÍVEIS'),
                  const SizedBox(height: AppSpacing.md),
                  ..._kCompatibleProviders.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: FigmaCompatibleDeviceCard(
                        icon: p.icon,
                        deviceName: p.name,
                        dataLabel: p.metrics,
                        onConnect: () => _showProviderDialog(context, p),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderDialog(BuildContext context, _ProviderSpec p) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FigmaColors.surfaceCard,
        title: Text(
          'Em breve: ${p.name}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FigmaColors.textPrimary,
          ),
        ),
        content: Text(
          'Integração com ${p.name} está em desenvolvimento. '
          'Em breve você poderá sincronizar BPM, sono, HRV e passos automaticamente.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            height: 1.5,
            color: FigmaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FigmaColors.brandCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        color: FigmaColors.textMuted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: FigmaDimensions.borderUniversal,
      ),
    );
  }
}

class _EmptyConnectedState extends StatelessWidget {
  const _EmptyConnectedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: 1.735,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.watch_outlined,
                size: 22,
                color: FigmaColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  'NENHUM DISPOSITIVO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Conecte um wearable abaixo para sincronizar BPM, sono e passos.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSpec {
  final String name;
  final String metrics;
  final IconData icon;

  const _ProviderSpec({
    required this.name,
    required this.metrics,
    required this.icon,
  });
}

const _kCompatibleProviders = <_ProviderSpec>[
  _ProviderSpec(
    name: 'Apple Watch',
    metrics: 'BPM · Sono · Passos · HRV',
    icon: Icons.watch_outlined,
  ),
  _ProviderSpec(
    name: 'Garmin',
    metrics: 'BPM · Sono · Passos · HRV',
    icon: Icons.track_changes_outlined,
  ),
  _ProviderSpec(
    name: 'Fitbit',
    metrics: 'BPM · Sono · ECG · SpO2',
    icon: Icons.health_and_safety_outlined,
  ),
  _ProviderSpec(
    name: 'Samsung Galaxy Watch',
    metrics: 'BPM · Sono · Passos',
    icon: Icons.watch_later_outlined,
  ),
  _ProviderSpec(
    name: 'Xiaomi Mi Band',
    metrics: 'BPM · Sono · Passos',
    icon: Icons.fitness_center_outlined,
  ),
  _ProviderSpec(
    name: 'Polar',
    metrics: 'BPM · ECG · Sono',
    icon: Icons.favorite_outline,
  ),
  _ProviderSpec(
    name: 'COROS',
    metrics: 'BPM · Sono · HRV',
    icon: Icons.directions_run_outlined,
  ),
  _ProviderSpec(
    name: 'Whoop',
    metrics: 'BPM · HRV · Recovery',
    icon: Icons.bolt_outlined,
  ),
];
