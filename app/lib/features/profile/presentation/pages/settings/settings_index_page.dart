import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'AJUSTES',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Coach, alertas e unidades',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: palette.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SettingsCard(
                    icon: Icons.smart_toy_outlined,
                    title: 'COACH',
                    subtitle: 'Personalidade, voz, frequência e feedback',
                    onTap: () => context.push('/profile/settings/coach'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    icon: Icons.notifications_outlined,
                    title: 'ALERTAS',
                    subtitle: 'Push, in-app, janela de silêncio',
                    onTap: () =>
                        context.push('/profile/settings/notifications'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    icon: Icons.straighten_outlined,
                    title: 'UNIDADES',
                    subtitle: 'Métrico / Imperial, pace, horário',
                    onTap: () => context.push('/profile/settings/units'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: palette.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
