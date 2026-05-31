import 'package:flutter/material.dart';
import 'package:runnin/core/analytics/analytics_service.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
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
            breadcrumb: 'SAÚDE',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'CONECTADAS'),
                  const SizedBox(height: AppSpacing.md),
                  const _EmptyConnectedState(),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'PLATAFORMAS DE SAÚDE'),
                  const SizedBox(height: AppSpacing.md),
                  const _PlatformsHelperText(),
                  const SizedBox(height: AppSpacing.md),
                  ..._kCompatibleProviders
                      .where((p) => _isAvailableNow(p))
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: FigmaCompatibleDeviceCard(
                            icon: p.icon,
                            deviceName: p.name,
                            dataLabel: p.metrics,
                            onConnect: () => _onConnectProvider(context, p),
                          ),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'INTEGRAÇÕES DIRETAS (EM BREVE)'),
                  const SizedBox(height: AppSpacing.md),
                  ..._kCompatibleProviders
                      .where((p) => !_isAvailableNow(p))
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: FigmaCompatibleDeviceCard(
                            icon: p.icon,
                            deviceName: p.name,
                            dataLabel: p.metrics,
                            onConnect: () => _onConnectProvider(context, p),
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

  /// Apple Health (iOS) + Google Health Connect (Android) já estão integrados
  /// via plugin `health`. Cards de marcas (Garmin, Polar, etc.) ficam em
  /// "INTEGRAÇÕES DIRETAS (EM BREVE)" porque exigem OAuth próprio do fabricante
  /// — não vão pelas plataformas de saúde do SO.
  bool _isAvailableNow(_ProviderSpec p) =>
      p.name == 'Apple Health' || p.name == 'Google Health Connect';

  void _onConnectProvider(BuildContext context, _ProviderSpec p) {
    analytics.logEvent('wearable_connect_tapped', params: {
      'provider': p.name,
      'available_now': _isAvailableNow(p),
    });
    if (_isAvailableNow(p) && healthSyncService.isSupported) {
      _connectViaHealthBridge(context, p);
      return;
    }
    _showProviderDialog(context, p);
  }

  Future<void> _connectViaHealthBridge(BuildContext context, _ProviderSpec p) async {
    analytics.logEvent('wearable_connect_started', params: {'provider': p.name});
    final granted = await healthSyncService.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      analytics.logEvent('wearable_connect_denied', params: {'provider': p.name});
      _showPermissionDeniedDialog(context, p);
      return;
    }
    analytics.logEvent('wearable_connect_granted', params: {'provider': p.name});
    // Permissão OK → sincroniza últimos 7d em background.
    healthSyncService.syncSince().then((count) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count amostras sincronizadas de ${p.name}.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado a ${p.name}. Sincronizando dados…'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDeniedDialog(BuildContext context, _ProviderSpec p) {
    final isApple = p.name == 'Apple Health';
    final settingsPath = isApple
        ? 'Ajustes do iPhone > Privacidade e Segurança > Saúde > runnin'
        : 'Configurações do Android > Apps > Health Connect > runnin';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FigmaColors.surfaceCard,
        title: Text(
          'Permissão negada',
          style: context.runninType.bodyMd.copyWith(
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
        content: Text(
          'Pra ler seus dados de ${p.name}, libere o acesso em:\n\n$settingsPath\n\n'
          'Depois volte aqui e tente conectar de novo.',
          style: context.runninType.bodySm.copyWith(
            height: 1.5,
            color: FigmaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: context.runninType.labelMd.copyWith(
                color: context.runninPalette.primary,
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
          style: context.runninType.bodyMd.copyWith(
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
        content: Text(
          'A integração direta com ${p.name} (via OAuth do fabricante) ainda '
          'está em desenvolvimento. Enquanto isso, se o seu dispositivo '
          'sincroniza dados com a Apple Health ou Google Health Connect, '
          'você já pode importar BPM, sono e passos por essas plataformas.',
          style: context.runninType.bodySm.copyWith(
            height: 1.5,
            color: FigmaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: context.runninType.labelMd.copyWith(
                color: context.runninPalette.primary,
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
      style: context.runninType.labelCaps.copyWith(
        color: FigmaColors.textMuted,
        fontWeight: FontWeight.w500,
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
          width: 1.041,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                size: 22,
                color: FigmaColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  'NENHUMA PLATAFORMA',
                  style: context.runninType.labelMd.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Conecte a Apple Health (iOS) ou o Google Health Connect (Android) '
            'abaixo para importar BPM, sono e passos do seu relógio ou celular.',
            style: context.runninType.bodyXs.copyWith(
              height: 1.5,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformsHelperText extends StatelessWidget {
  const _PlatformsHelperText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'A sincronização acontece pela plataforma de saúde do seu sistema — '
      'não conectamos diretamente ao relógio. Apple Health lê dados de Apple '
      'Watch e iPhone; Google Health Connect lê de Galaxy Watch, Mi Band e '
      'outros wearables compatíveis com Health Connect.',
      style: context.runninType.bodyXs.copyWith(
        height: 1.5,
        color: FigmaColors.textMuted,
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
  // Plataformas de saúde — integração disponível hoje via plugin `health`
  // (HealthKit no iOS, Health Connect no Android). Lê dados dos relógios/
  // celulares que sincronizam com essas plataformas, não conecta direto.
  _ProviderSpec(
    name: 'Apple Health',
    metrics: 'iPhone, Apple Watch · BPM · Sono · Passos · HRV',
    icon: Icons.health_and_safety_outlined,
  ),
  _ProviderSpec(
    name: 'Google Health Connect',
    metrics: 'Galaxy, Mi Band e Android · BPM · Sono · Passos',
    icon: Icons.health_and_safety_outlined,
  ),
  // Integrações diretas (cloud-to-cloud via OAuth do fabricante) — em
  // desenvolvimento. Por enquanto, esses dispositivos só chegam se forem
  // sincronizados via Health Connect/Apple Health.
  _ProviderSpec(
    name: 'Garmin Connect',
    metrics: 'BPM · Sono · Passos · HRV (via OAuth)',
    icon: Icons.track_changes_outlined,
  ),
  _ProviderSpec(
    name: 'Fitbit',
    metrics: 'BPM · Sono · ECG · SpO2 (via OAuth)',
    icon: Icons.favorite_outline,
  ),
  _ProviderSpec(
    name: 'Polar Flow',
    metrics: 'BPM · ECG · Sono (via OAuth)',
    icon: Icons.monitor_heart_outlined,
  ),
  _ProviderSpec(
    name: 'COROS',
    metrics: 'BPM · Sono · HRV (via OAuth)',
    icon: Icons.directions_run_outlined,
  ),
  _ProviderSpec(
    name: 'Whoop',
    metrics: 'BPM · HRV · Recovery (via OAuth)',
    icon: Icons.bolt_outlined,
  ),
];
