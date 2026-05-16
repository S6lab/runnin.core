import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/gamification/levels.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

/// Aggregated profile data shown in PERFIL root. Computed once on page load.
class _AccountData {
  final UserProfile? profile;
  final List<Run> runs;
  final int totalXp;
  final LevelProgress level;
  final int streakDays;
  final double totalKm;
  final int runsCount;

  _AccountData({
    required this.profile,
    required this.runs,
    required this.totalXp,
    required this.level,
    required this.streakDays,
    required this.totalKm,
    required this.runsCount,
  });

  factory _AccountData.empty() => _AccountData(
        profile: null,
        runs: const [],
        totalXp: 0,
        level: computeLevel(0),
        streakDays: 0,
        totalKm: 0,
        runsCount: 0,
      );
}

int _computeStreak(List<Run> runs) {
  final runDays = runs.map((r) {
    final d = DateTime.tryParse(r.createdAt)?.toLocal();
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }).whereType<DateTime>().toSet();
  int streak = 0;
  DateTime day = DateTime.now();
  day = DateTime(day.year, day.month, day.day);
  while (runDays.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _userDs = UserRemoteDatasource();
  final _runDs = RunRemoteDatasource();
  _AccountData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _userDs.getMe(),
        _runDs.listRuns(limit: 90),
      ]);
      final profile = results[0] as UserProfile?;
      final allRuns = results[1] as List<Run>;
      final runs = allRuns.where((r) => r.status == 'completed').toList();
      final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
      final totalKm = runs.fold<double>(0, (s, r) => s + r.distanceM) / 1000;
      if (!mounted) return;
      setState(() {
        _data = _AccountData(
          profile: profile,
          runs: runs,
          totalXp: totalXp,
          level: computeLevel(totalXp),
          streakDays: _computeStreak(runs),
          totalKm: totalKm,
          runsCount: runs.length,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = _AccountData.empty();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? _AccountData.empty();
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const _TopNav(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        _ProfileHeader(data: data),
                        const SizedBox(height: AppSpacing.xl),
                        _StatsCards(data: data),
                        const SizedBox(height: AppSpacing.md),
                        _UserInfoCards(data: data),
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
  final _AccountData data;
  const _ProfileHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data.profile?.name.trim().isNotEmpty ?? false)
        ? data.profile!.name.trim()
        : 'Atleta';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final isPremium = data.profile?.premium ?? false;
    final runsLabel = data.runsCount == 0
        ? 'Nenhuma corrida ainda'
        : '${data.runsCount} corrida${data.runsCount == 1 ? '' : 's'} · ${data.totalKm.toStringAsFixed(1)}km total';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FigmaColors.brandCyan,
                borderRadius: FigmaBorderRadius.zero,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: GoogleFonts.jetBrainsMono(
                  color: FigmaColors.bgBase,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                        'Nível ${data.level.currentLevel} · ${data.level.currentName}',
                        style: GoogleFonts.jetBrainsMono(
                          color: FigmaColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isPremium) ...[
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
            runsLabel,
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
  final _AccountData data;
  const _StatsCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final xpLabel = data.level.isMax
        ? 'MAX'
        : '${data.level.xpIntoLevel}/${data.level.xpForNextLevel}';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'STREAK',
            value: '${data.streakDays}',
            valueColor: FigmaColors.brandCyan,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'XP',
            value: xpLabel,
            valueColor: FigmaColors.brandOrange,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'NÍVEL',
            value: '${data.level.currentLevel}',
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
  final _AccountData data;
  const _UserInfoCards({required this.data});

  static int? _ageFromBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    // expected "dd/mm/yyyy"
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(birthDate);
    if (m == null) return null;
    final birth = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }

  static String _stripUnit(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return raw.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final age = _ageFromBirthDate(profile?.birthDate);
    final hasAnyEmpty = profile == null ||
        (profile.weight == null || profile.weight!.isEmpty) ||
        (profile.height == null || profile.height!.isEmpty) ||
        age == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoCard(label: 'PESO', value: _stripUnit(profile?.weight), unit: 'kg'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _InfoCard(label: 'ALTURA', value: _stripUnit(profile?.height), unit: 'cm'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _InfoCard(label: 'IDADE', value: age?.toString() ?? '—', unit: 'anos'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _InfoCard(label: 'FREQ', value: '${profile?.frequency ?? 3}x', unit: '/sem'),
            ),
          ],
        ),
        if (hasAnyEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () => context.push('/profile/edit'),
            child: Text(
              'Preencher dados →',
              style: GoogleFonts.jetBrainsMono(
                color: FigmaColors.brandCyan,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
          onTap: () => context.push('/paywall?next=/profile'),
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
