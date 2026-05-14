import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/theme_controller.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Column(
        children: [
          const _TopNav(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(23.99, 0, 23.99, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const _ProfileHeader(),
                  const SizedBox(height: 24),
                  const _StatsCards(),
                  const SizedBox(height: 12),
                  const _UserInfoCards(),
                  const SizedBox(height: 32),
                  const _SkinSection(),
                  const SizedBox(height: 32),
                  const _MenuSection(),
                  const SizedBox(height: 32),
                  _BottomActions(),
                  const SizedBox(height: 16),
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
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF050510).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23.99),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RUNNIN.AI',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'PROF',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                color: const Color(0xFF00d4ff),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Text(
                'L',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF050510),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Name and level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lucas',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Nível 7 · ·',
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00d4ff),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF050510),
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
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '24 corridas · 98.5km total',
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.5),
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
            valueColor: const Color(0xFF00d4ff),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'XP',
            value: '340/500',
            valueColor: const Color(0xFFff6b35),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'BADGES',
            value: '7/21',
            valueColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.735,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
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
        const SizedBox(width: 8),
        Expanded(
          child: _InfoCard(label: 'ALTURA', value: '—', unit: 'cm'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoCard(label: 'IDADE', value: '—', unit: 'anos'),
        ),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.735,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.3),
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '01',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF00d4ff),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Escolha a paleta de cores do app',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
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
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ThemeCard(skin: RunninSkin.sangue, label: 'Sangue'),
        _ThemeCard(skin: RunninSkin.magenta, label: 'Magenta'),
        _ThemeCard(skin: RunninSkin.volt, label: 'Volt'),
        _ThemeCard(skin: RunninSkin.artico, label: 'Ártico'),
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
              ? const Color(0xFF00d4ff).withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00d4ff)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.735,
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: palette.secondary,
                          borderRadius: BorderRadius.circular(2),
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
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
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
                    color: const Color(0xFF00d4ff),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '02',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF00d4ff),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuItem(
          icon: Icons.emoji_events_outlined,
          title: 'GAMIFICAÇÃO',
          subtitle: 'Badges, XP, Streak',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.favorite_outline,
          title: 'SAÚDE',
          subtitle: 'BPM, Zonas, Wearable',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.settings_outlined,
          title: 'AJUSTES',
          subtitle: 'Coach, Alertas, Unidades',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.star_outline,
          title: 'ASSINATURA',
          subtitle: 'Premium',
          onTap: () {},
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
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.735,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.6),
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
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.4),
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
                color: Colors.white.withValues(alpha: 0.3),
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
            color: Colors.white.withValues(alpha: 0.03),
            child: InkWell(
              onTap: () => context.push('/profile/edit'),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.735,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Editar perfil ↗',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Logout button
        SizedBox(
          height: 43,
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              // TODO: Implement logout
            },
            child: Center(
              child: Text(
                'Logout',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
