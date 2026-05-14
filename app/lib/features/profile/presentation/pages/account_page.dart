import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _signingOut = false;
  final _userDs = UserRemoteDatasource();
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _userDs.getMe();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _showLogoutConfirmation() async {
    final palette = context.runninPalette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Sair da conta?', style: TextStyle(color: palette.text)),
        content: Text(
          'Você será desconectado e redirecionado para a tela de login.',
          style: TextStyle(color: palette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SAIR', style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileName = _profile?.name.trim();
    final displayName = user?.displayName?.trim();
    final name = (profileName?.isNotEmpty == true)
        ? profileName!
        : (displayName?.isNotEmpty == true)
            ? displayName!
            : 'Lucas';
    final initial = name[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Column(
          children: [
            _TopNav(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(23.99, 24, 23.99, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(name: name, initial: initial),
                    const SizedBox(height: 24),
                    const _StatsCardsRow(),
                    const SizedBox(height: 12),
                    const _UserInfoCards(),
                    const SizedBox(height: 32),
                    const _SkinSection(),
                    const SizedBox(height: 32),
                    const _MenuSection(),
                    const SizedBox(height: 32),
                    _BottomActions(
                      signingOut: _signingOut,
                      onEditProfile: () => context.push('/profile/edit'),
                      onLogout: _showLogoutConfirmation,
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

// ── Top Navigation Bar ────────────────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 23.99, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF050510).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'RUNNIN',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: palette.text,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: palette.primary),
                child: Text(
                  '.AI',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.background,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Text(
              'PROF',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String initial;

  const _ProfileHeader({required this.name, required this.initial});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: palette.primary,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF050510),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Nível 7 · · ',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        color: palette.primary,
                        child: Text(
                          'PREMIUM',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: const Color(0xFF050510),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '24 corridas · 98.5km total',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stats Cards Row (STREAK / XP / BADGES) ───────────────────────────────────

class _StatsCardsRow extends StatelessWidget {
  const _StatsCardsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'STREAK',
            value: '12',
            unit: 'dias',
            valueColor: const Color(0xFF00d4ff),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'XP',
            value: '340',
            unit: '/500',
            valueColor: const Color(0xFFff6b35),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'BADGES',
            value: '7',
            unit: '/21',
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
  final String unit;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── User Info Cards (PESO / ALTURA / IDADE / FREQ) ────────────────────────────

class _UserInfoCards extends StatelessWidget {
  const _UserInfoCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _InfoCard(label: 'PESO', value: '—', unit: 'kg')),
        SizedBox(width: 8),
        Expanded(child: _InfoCard(label: 'ALTURA', value: '—', unit: 'cm')),
        SizedBox(width: 8),
        Expanded(child: _InfoCard(label: 'IDADE', value: '—', unit: 'anos')),
        SizedBox(width: 8),
        Expanded(child: _InfoCard(label: 'FREQ', value: '3x', unit: '/sem')),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SKIN Section ──────────────────────────────────────────────────────────────

class _SkinSection extends StatelessWidget {
  const _SkinSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SKIN',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: palette.primary,
              child: Text(
                '01',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF050510),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Escolha a paleta de cores do app',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 20),
        _ThemeCardsGrid(),
      ],
    );
  }
}

class _ThemeCardsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ThemeCard(skin: RunninSkin.artico, label: 'Ártico'),
        _ThemeCard(skin: RunninSkin.magenta, label: 'Magenta'),
        _ThemeCard(skin: RunninSkin.sangue, label: 'Sangue'),
        _ThemeCard(skin: RunninSkin.volt, label: 'Volt'),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final RunninSkin skin;
  final String label;

  const _ThemeCard({required this.skin, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = skin.palette;
    final isActive = context.runninPalette == palette;

    return InkWell(
      onTap: () => themeController.setSkin(skin),
      child: Container(
        width: 156,
        height: 103,
        decoration: BoxDecoration(
          color: isActive
              ? palette.primary.withValues(alpha: 0.06)
              : palette.surface,
          border: Border.all(
            color: isActive ? palette.primary : palette.border,
            width: 1.735,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  if (isActive)
                    Text(
                      'ATIVA',
                      style: GoogleFonts.jetBrainsMono(
                        color: palette.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      color: isActive
                          ? palette.text
                          : palette.text.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            value: 0.4,
                            backgroundColor: palette.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                palette.primary),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            value: 0.4,
                            backgroundColor: palette.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                palette.secondary),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            value: 0.2,
                            backgroundColor: palette.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                palette.tertiary),
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
      ),
    );
  }
}

// ── MENU Section ──────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'MENU',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: palette.primary,
              child: Text(
                '02',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF050510),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuItem(
          icon: Icons.emoji_events_outlined,
          title: 'GAMIFICAÇÃO',
          subtitle: 'Badges, XP, Streak',
          onTap: () => GoRouter.of(context).push('/gamification'),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.favorite_border,
          title: 'SAÚDE',
          subtitle: 'BPM, Zonas, Wearable',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.tune_outlined,
          title: 'AJUSTES',
          subtitle: 'Coach, Alertas, Unidades',
          onTap: () => GoRouter.of(context).push('/profile/account'),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.workspace_premium_outlined,
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
    final palette = context.runninPalette;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.735,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: palette.primary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '↗',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Actions ────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final bool signingOut;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  const _BottomActions({
    required this.signingOut,
    required this.onEditProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 47,
          width: double.infinity,
          child: Material(
            color: Colors.white.withValues(alpha: 0.03),
            child: InkWell(
              onTap: onEditProfile,
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
        SizedBox(
          height: 43,
          width: double.infinity,
          child: GestureDetector(
            onTap: signingOut ? null : onLogout,
            child: Center(
              child: signingOut
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    )
                  : Text(
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
