import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Ajustes',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsCard(
                    icon: Icons.smart_toy_outlined,
                    title: 'COACH',
                    subtitle: 'Personalidade, voz, frequência e feedback',
                    onTap: () => context.push('/profile/settings/coach'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsCard(
                    icon: Icons.notifications_outlined,
                    title: 'ALERTAS',
                    subtitle: 'Push, in-app, janela de silêncio',
                    onTap: () =>
                        context.push('/profile/settings/notifications'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(
            color: FigmaColors.borderDefault,
            width: AppDimensions.borderUniversal,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: FigmaColors.brandCyan, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      color: FigmaColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      color: FigmaColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '↗',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.textDim,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
