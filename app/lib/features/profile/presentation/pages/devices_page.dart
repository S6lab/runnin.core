import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_device_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final _remote = UserRemoteDatasource();
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _remote.getMe();
      if (mounted) {
        setState(() {
          _profile = profile;
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
      body: Column(
        children: [
          const _TopNav(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _FieldLabel(label: 'DISPOSITIVOS'),
                  const SizedBox(height: 8),
                  if (_loading)
                    const _LoadingState()
                  else if (_profile?.hasWearable == true)
                    _ConnectedDevice(userProfile: _profile!)
                  else
                    _CompatibleDevices(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    return FigmaTopNav(
      breadcrumb: 'Perfil / Saúde / Dispositivos',
      showBackButton: true,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: FigmaColors.brandCyan,
        strokeWidth: 1.5,
      ),
    );
  }
}

class _ConnectedDevice extends StatelessWidget {
  final UserProfile userProfile;

  const _ConnectedDevice({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return FigmaDeviceConnectedCard(
      deviceName: 'Garmin Forerunner 255',
      platformLabel: 'Android / iOS',
      dataChips: ['BPM', 'STEPS', 'SLEEP', 'HRV'],
      onSync: () => _showSyncToast(context),
    );
  }

  void _showSyncToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sincronizando com Garmin...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CompatibleDevices extends StatelessWidget {
  const _CompatibleDevices();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'COMPATÍVEIS'),
        const SizedBox(height: 12),
        _CompatibleDeviceItem(
          icon: Icons.watch_later_outlined,
          deviceName: 'Apple Watch',
          dataLabel: 'BPM · Sono · Passos',
          onConnect: () => _showComingSoon(context),
        ),
        const SizedBox(height: 12),
        _CompatibleDeviceItem(
          icon: Icons.track_changes_outlined,
          deviceName: 'Samsung Galaxy Watch',
          dataLabel: 'BPM · Sono · Passos',
          onConnect: () => _showComingSoon(context),
        ),
        const SizedBox(height: 12),
        _CompatibleDeviceItem(
          icon: Icons.health_and_safety_outlined,
          deviceName: 'Fitbit Sense',
          dataLabel: 'BPM · Sono · ECG',
          onConnect: () => _showComingSoon(context),
        ),
        const SizedBox(height: 12),
        _CompatibleDeviceItem(
          icon: Icons.fitness_center_outlined,
          deviceName: 'Polar H10',
          dataLabel: 'BPM · ECG · Sono',
          onConnect: () => _showComingSoon(context),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Em breve'),
        content: const Text('Integração OAuth pendente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CompatibleDeviceItem extends StatelessWidget {
  final IconData icon;
  final String deviceName;
  final String dataLabel;
  final VoidCallback onConnect;

  const _CompatibleDeviceItem({
    required this.icon,
    required this.deviceName,
    required this.dataLabel,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConnect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: FigmaColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deviceName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      height: 19.5 / 13,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.textPrimary,
                    ),
                  ),
                  Text(
                    dataLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Conectar  ↗',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                letterSpacing: 0.55,
                fontWeight: FontWeight.w500,
                color: FigmaColors.brandCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: FigmaColors.textPrimary,
      ),
    );
  }
}
