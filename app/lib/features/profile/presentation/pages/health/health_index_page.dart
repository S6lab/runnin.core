import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthIndexPage extends StatelessWidget {
  const HealthIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            FigmaTopNav(
              breadcrumb: 'PERFIL / SAÚDE',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'SAÚDE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.44,
                        color: palette.text,
                        height: 24.2 / 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'BPM, Zonas, Wearable, Exames',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: palette.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _HealthCard(
                      title: 'TENDÊNCIAS',
                      subtitle: 'BPM médio, Pace, Distância semanal',
                      onTap: () => context.push('/profile/health/trends'),
                      available: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _HealthCard(
                      title: 'ZONAS',
                      subtitle: 'Distribuição de frequência cardíaca',
                      onTap: () => context.push('/profile/health/zones'),
                      available: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _HealthCard(
                      title: 'DISPOSITIVOS',
                      subtitle: 'Wearables conectados',
                      onTap: () => context.push('/profile/health/devices'),
                      available: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _HealthCard(
                      title: 'EXAMES',
                      subtitle: 'Histórico de exames físicos',
                      onTap: () => context.push('/profile/health/exams'),
                      available: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.available,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 1.0),
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              color: available ? palette.primary : palette.muted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: palette.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              available ? Icons.chevron_right : Icons.lock_outline,
              color: palette.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
