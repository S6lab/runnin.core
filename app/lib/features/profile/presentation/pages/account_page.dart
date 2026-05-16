import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const _TopNav(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const _ProfileHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  const _StatsCards(),
                  const SizedBox(height: AppSpacing.md),
                  const _UserInfoCards(),
                  const SizedBox(height: AppSpacing.xxl),
                  const _SkinSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const _MenuSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _BottomActions(),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Navigation ──────────────────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    return FigmaTopNav(
      breadcrumb: 'Perfil',
      showBackButton: false,
    );
  }
}

// ── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FigmaColors.brandCyan,
                borderRadius: FigmaBorderRadius.zero,
              ),
              alignment: Alignment.center,
              child: Text(
                'L',
                style: GoogleFonts.jetBrainsMono(
                  color: FigmaColors.bgBase,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Name and level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lucas',
                    style: GoogleFonts.jetBrainsMono(
                      color: FigmaColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        'Nível 7 · ·',
                        style: GoogleFonts.jetBrainsMono(
                          color: FigmaColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FigmaColors.brandCyan,
                          borderRadius: FigmaBorderRadius.zero,
                        ),
                        child: Text(
                          'PREMIUM',
                          style: GoogleFonts.jetBrainsMono(
                            color: FigmaColors.bgBase,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '24 corridas · 98.5km total',
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Cards ─────────────────────────────────────────────────────────────

class _StatsCards extends StatelessWidget {
  const _StatsCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'STREAK',
            value: '12',
            valueColor: FigmaColors.brandCyan,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'XP',
            value: '340/500',
            valueColor: FigmaColors.brandOrange,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'BADGES',
            value: '7/21',
            valueColor: FigmaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 14),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: AppDimensions.borderUniversal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: AppDimensions.borderUniversal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Info Cards ─────────────────────────────────────────────────────────

class _UserInfoCards extends StatelessWidget {
  const _UserInfoCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(label: 'PESO', value: '—', unit: 'kg'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _InfoCard(label: 'ALTURA', value: '—', unit: 'cm'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _InfoCard(label: 'IDADE', value: '—', unit: 'anos'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _InfoCard(label: 'FREQ', value: '3x', unit: '/sem'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 10),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: AppDimensions.borderUniversal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: AppDimensions.borderUniversal - 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.textDim,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skin Section ────────────────────────────────────────────────────────────

class _SkinSection extends StatelessWidget {
  const _SkinSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SKIN',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '01',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.brandCyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Escolha a paleta de cores do app',
          style: GoogleFonts.jetBrainsMono(
            color: FigmaColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _ThemeCardsGrid(),
      ],
    );
  }
}

class _ThemeCardsGrid extends StatelessWidget {
  const _ThemeCardsGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        _ThemeCard(skin: RunninSkin.sangue, label: 'SANGUE'),
        _ThemeCard(skin: RunninSkin.magenta, label: 'MAGENTA'),
        _ThemeCard(skin: RunninSkin.volt, label: 'VOLT'),
        _ThemeCard(skin: RunninSkin.artico, label: 'ÁRTICO'),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final RunninSkin skin;
  final String label;

  const _ThemeCard({
    required this.skin,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = skin.palette;
    final currentPalette = context.runninPalette;
    final isActive = currentPalette == palette;

    return InkWell(
      onTap: () => themeController.setSkin(skin),
      child: Container(
        width: 156,
        height: 103,
        decoration: BoxDecoration(
          color: isActive
              ? FigmaColors.skinActiveBg
              : FigmaColors.surfaceCard,
          border: Border.all(
            color: isActive
                ? FigmaColors.brandCyan
                : FigmaColors.borderDefault,
            width: AppDimensions.borderUniversal,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Color squares
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: FigmaBorderRadius.zero,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: palette.secondary,
                          borderRadius: FigmaBorderRadius.zero,
                        ),
                      ),
                    ],
                  ),
                  // Label and progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          color: isActive
                              ? FigmaColors.textPrimary
                              : FigmaColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: FigmaBorderRadius.zero,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 3,
                                color: palette.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: palette.secondary.withValues(alpha: 0.4),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: palette.border,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ATIVA label
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Text(
                  'ATIVA',
                  style: GoogleFonts.jetBrainsMono(
                    color: FigmaColors.brandCyan,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: AppDimensions.borderUniversal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Menu Section ────────────────────────────────────────────────────────────

void _showComingSoon(BuildContext context, String featureLabel) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$featureLabel — em breve.'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'MENU',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '02',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.brandCyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _MenuItem(
          icon: Icons.emoji_events_outlined,
          title: 'GAMIFICAÇÃO',
          subtitle: 'Badges, XP, Streak',
          onTap: () => context.push('/gamification'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuItem(
          icon: Icons.chat_bubble_outline,
          title: 'FALAR COM COACH.AI',
          subtitle: 'Chat com o seu coach',
          onTap: () => context.push('/coach'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuItem(
          icon: Icons.lock_outline,
          title: 'CONTA & ACESSO',
          subtitle: 'Email, telefone, login',
          onTap: () => context.push('/profile/access'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuItem(
          icon: Icons.favorite_outline,
          title: 'SAÚDE',
          subtitle: 'BPM, Zonas, Wearable',
          onTap: () => context.push('/profile/health'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuItem(
          icon: Icons.settings_outlined,
          title: 'AJUSTES',
          subtitle: 'Coach, Alertas, Unidades',
          onTap: () => context.push('/profile/settings'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuItem(
          icon: Icons.star_outline,
          title: 'ASSINATURA',
          subtitle: 'Premium',
          onTap: () => _showComingSoon(context, 'Assinatura Premium'),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(
            color: FigmaColors.borderDefault,
            width: AppDimensions.borderUniversal,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: FigmaColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      color: FigmaColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppDimensions.borderUniversal - 0.7,
                    ),
                  ),
                  const SizedBox(height: 3),
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

// ── Bottom Actions ──────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Editar perfil button
        SizedBox(
          height: 47,
          width: double.infinity,
          child: Material(
            color: FigmaColors.surfaceCard,
            child: InkWell(
              onTap: () => context.push('/profile/edit'),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: FigmaColors.borderDefault,
                    width: AppDimensions.borderUniversal,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: FigmaColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Editar perfil ↗',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Logout button
        SizedBox(
          height: 43,
          width: double.infinity,
          child: GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              markOnboardingPending();
              if (context.mounted) context.go('/login');
            },
            child: Center(
              child: Text(
                'Logout',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textGhost,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
