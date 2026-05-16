import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthIndexPage extends StatelessWidget {
  const HealthIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            FigmaTopNav(
              breadcrumb: 'Perfil / Saúde',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    _SectionHeader(label: 'SAÚDE', index: '01'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'BPM, Zonas, Wearable, Exames',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: FigmaColors.textMuted,
                        height: 19.5 / 13,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              color: available ? FigmaColors.brandCyan : FigmaColors.textMuted,
              size: 19.98,
            ),
            const SizedBox(width: 11.983),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textPrimary,
                      height: 21 / 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textMuted,
                      height: 19.5 / 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              available ? '↗' : 'em breve',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textMuted,
                height: 19.5 / 13,
              ),
            ),
          ],
        ),
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
