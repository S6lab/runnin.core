import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/home/domain/use_cases/get_home_data_use_case.dart';
import 'package:runnin/features/home/presentation/cubit/home_cubit.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';
import 'package:runnin/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/notification_tile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeCubit()..load()),
        BlocProvider(create: (_) => NotificationsCubit()..load()),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  @override
  void initState() {
    super.initState();
    final cachedStatus = onboardingCacheStatus();
    if (cachedStatus != true) {
      _checkOnboarding(cachedStatus);
    }
  }

  Future<void> _checkOnboarding(bool? cachedStatus) async {
    if (cachedStatus == false) {
      markOnboardingPending();
      if (mounted) context.go('/onboarding');
      return;
    }

    try {
      final profile = await UserRemoteDatasource().getMe();
      if (profile == null || !profile.onboarded) {
        markOnboardingPending();
        if (mounted) context.go('/onboarding');
      } else {
        markOnboardingDone();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(17.7, 17.7, 17.7, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: 20),
                  if (state is HomeLoading) ...[
                    const _LoadingCard(),
                    const SizedBox(height: 17.7),
                    const _LoadingCard(),
                  ] else if (state is HomeError) ...[
                    _ErrorCard(
                      message: state.message,
                      onRetry: () => context.read<HomeCubit>().load(),
                    ),
                  ] else if (state is HomeLoaded) ...[
                    _CyberStatusBar(data: state.data),
                    const SizedBox(height: 20),
                    _UserInfoCards(data: state.data),
                    const SizedBox(height: 20),
                    const _SkinSection(),
                    const SizedBox(height: 20),
                    _IniciarSessaoButton(data: state.data),
                    const SizedBox(height: 20),
                    const _CoachNotifications(),
                    const SizedBox(height: 20),
                    _SemanaSection(data: state.data),
                    const SizedBox(height: 20),
                    _CoachAiWeeklySummary(data: state.data),
                    const SizedBox(height: 20),
                    _PerformanceSection(data: state.data),
                    const SizedBox(height: 20),
                    _StatusCorporalSection(data: state.data),
                    const SizedBox(height: 20),
                    const _MenuSection(),
                    const SizedBox(height: 20),
                  ] else ...[
                    const _LoadingCard(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;

    // Cyber theme: Use JetBrains Mono for header
    return Row(
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
        Row(
          children: [
            InkWell(
              onTap: () => context.push('/dashboard'),
              child: Icon(
                Icons.bar_chart_outlined,
                size: 22,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 14),
            InkWell(
              onTap: () => context.push('/profile'),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  color: palette.surface,
                  shape: BoxShape.circle,
                  image: user?.photoURL != null
                      ? DecorationImage(
                          image: NetworkImage(user!.photoURL!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: user?.photoURL == null
                    ? Text(
                        _initial(user),
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _initial(User? user) {
    final name = user?.displayName?.trim();
    if (name == null || name.isEmpty) return 'R';
    return name[0].toUpperCase();
  }
}

// ─── Cyber Status Bar ─────────────────────────────────────────────────────────

class _CyberStatusBar extends StatelessWidget {
  final HomeData data;
  const _CyberStatusBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final firstName = user?.displayName?.split(' ').firstOrNull ?? 'ATLETA';
    final dateLabel = _formatDate(now);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: palette.text.withValues(alpha: 0.06),
            width: 1.735,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '● ',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 12,
                  letterSpacing: 0.96,
                ),
              ),
              Text(
                '$dateLabel — $greeting, ${firstName.toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.text.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 0.96,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _DeviceChip(
                label: 'WATCH',
                icon: Icons.watch_outlined,
                active: data.profile?.hasWearable == true,
                palette: palette,
              ),
              const SizedBox(width: 8),
              _DeviceChip(
                label: 'AUDIO',
                icon: Icons.headphones_outlined,
                active: false,
                palette: palette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'BOM DIA';
    if (hour < 18) return 'BOA TARDE';
    return 'BOA NOITE';
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    final day = d.day.toString().padLeft(2, '0');
    return '$day.${months[d.month]}.${d.year}';
  }
}

class _DeviceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final RunninPalette palette;

  const _DeviceChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.text.withValues(alpha: 0.06),
        border: Border.all(
          color: palette.text.withValues(alpha: 0.08),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? palette.primary
                  : palette.text.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 12, color: palette.text.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: palette.text.withValues(alpha: 0.5),
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User Info Cards ─────────────────────────────────────────────────────────

class _UserInfoCards extends StatelessWidget {
  final HomeData data;
  const _UserInfoCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final weight = data.profile?.weight ?? '—';
    final height = data.profile?.height ?? '—';
    final age = _calculateAge(data.profile?.birthDate);
    final frequency = data.profile?.frequency?.toString() ?? '—';

    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            label: 'PESO',
            value: weight,
            unit: weight == '—' ? '' : 'kg',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoCard(
            label: 'ALTURA',
            value: height,
            unit: height == '—' ? '' : 'cm',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoCard(
            label: 'IDADE',
            value: age,
            unit: age == '—' ? '' : 'anos',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoCard(
            label: 'FREQ',
            value: '${frequency}x',
            unit: '/sem',
          ),
        ),
      ],
    );
  }

  String _calculateAge(String? birthDate) {
    if (birthDate == null) return '—';
    final birth = DateTime.tryParse(birthDate);
    if (birth == null) return '—';
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age.toString();
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
    final palette = context.runninPalette;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: palette.text.withValues(alpha: 0.03),
        border: Border.all(
          color: palette.text.withValues(alpha: 0.08),
          width: 1.735,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 0.9,
              color: palette.text.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              unit,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: palette.text.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Iniciar Sessão ───────────────────────────────────────────────────────────

class _IniciarSessaoButton extends StatelessWidget {
  final HomeData data;
  const _IniciarSessaoButton({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    if (data.plan == null) {
      return _CoachMessageCard(
        palette: palette,
        message:
            'Seu app esta pronto para gerar o primeiro bloco de treino. Complete o setup no modulo de treino para liberar a sessao do dia.',
        ctaLabel: 'GERAR MEU PLANO ↗',
        onCta: () => context.push('/training'),
      );
    }

    if (data.plan!.isGenerating) {
      return Container(
        padding: const EdgeInsets.all(17.7),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: palette.primary,
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Gerando seu plano...',
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final session = data.todaySession;

    // Coach AI message block from Figma
    final coachMessage = session == null
        ? 'Nenhuma sessao planejada para hoje. Use uma corrida livre ou revise a distribuicao da semana no modulo de treino.'
        : 'Easy Run hoje — pace controlado entre ${session.targetPace ?? "livre"} e foco em cadencia e respiracao. Nao acelere nos ultimos 2km.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CyberTodayCard(data: data),
        const SizedBox(height: 20),
        _CoachMessageCard(
          palette: palette,
          message: coachMessage,
          ctaLabel:
              session != null ? 'INICIAR SESSAO ↗' : 'INICIAR CORRIDA LIVRE ↗',
          onCta: () => context.push('/prep'),
        ),
      ],
    );
  }
}

class _CoachMessageCard extends StatelessWidget {
  final RunninPalette palette;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  const _CoachMessageCard({
    required this.palette,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
           decoration: BoxDecoration(
             color: palette.secondary.withValues(alpha: 0.02),
             border: Border(
               left: BorderSide(color: palette.secondary, width: 1.735),
             ),
           ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COACH.AI',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.secondary,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: GoogleFonts.jetBrainsMono(
                  color: palette.text.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onCta,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: palette.primary,
            child: Text(
              ctaLabel,
              style: GoogleFonts.jetBrainsMono(
                color: palette.background,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CyberTodayCard extends StatelessWidget {
  final HomeData data;
  const _CyberTodayCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final session = data.todaySession;
    final now = DateTime.now();
    final weekNum = _isoWeekNumber(now);
    final dayName = _dayName(now.weekday);
    final sessionNum = data.completedSessions + 1;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            palette.background,
            Colors.transparent,
            Colors.transparent,
            palette.background,
          ],
          stops: const [0, 0.25, 0.5, 1],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'HOJE',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.text,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  height: 0.88,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '0$sessionNum',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                color: palette.primary,
                child: Text(
                  session?.type.toUpperCase() ?? 'LIVRE',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.background,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.65,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$dayName · SEM $weekNum',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.text.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (session != null) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatKm(session.distanceKm).replaceAll(' km', '')}K',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.text,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2.5,
                    height: 0.85,
                  ),
                ),
                const SizedBox(width: 16),
                if (session.targetPace != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: session.targetPace!,
                                style: GoogleFonts.jetBrainsMono(
                                  color: palette.secondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: '/km',
                                style: GoogleFonts.jetBrainsMono(
                                  color: palette.text.withValues(alpha: 0.55),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '~${_estMin(session.distanceKm, session.targetPace)}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: palette.text.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.26,
                                ),
                              ),
                              TextSpan(
                                text: 'min',
                                style: GoogleFonts.jetBrainsMono(
                                  color: palette.text.withValues(alpha: 0.55),
                                  fontSize: 7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _isoWeekNumber(DateTime date) {
    final doy = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final dow = date.weekday;
    return ((doy - dow + 10) / 7).floor();
  }

  String _dayName(int weekday) {
    const days = [
      '',
      'SEGUNDA',
      'TERCA',
      'QUARTA',
      'QUINTA',
      'SEXTA',
      'SABADO',
      'DOMINGO',
    ];
    return days[weekday];
  }

  String _estMin(double km, String? pace) {
    if (pace == null) return '--';
    final parts = pace.split(':');
    if (parts.length != 2) return '--';
    final min = int.tryParse(parts[0]) ?? 0;
    final sec = int.tryParse(parts[1]) ?? 0;
    final totalSec = (min * 60 + sec) * km;
    return (totalSec / 60).round().toString();
  }
}

// ─── Coach Notificações ───────────────────────────────────────────────────────

class _CoachNotifications extends StatelessWidget {
  const _CoachNotifications();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (state is! NotificationsLoaded) return const SizedBox.shrink();
        if (state.items.isEmpty) return const SizedBox.shrink();
        return _CoachNotificationsList(items: state.items);
      },
    );
  }
}

class _CoachNotificationsList extends StatelessWidget {
  final List<AppNotification> items;
  const _CoachNotificationsList({required this.items});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final cubit = context.read<NotificationsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined, size: 22, color: palette.muted),
            const SizedBox(width: 6),
            Text(
              'COACH.AI > NOTIFICAÇÕES',
              style: context.runninType.labelCaps,
            ),
            const SizedBox(width: 8),
            AppTag(label: '${items.length}', color: palette.primary),
            const Spacer(),
            InkWell(
              onTap: cubit.clear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('LIMPAR', style: context.runninType.labelCaps),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(border: Border.all(color: palette.border)),
          child: Column(
            children: items
                .map(
                  (item) => NotificationTile(
                    icon: item.icon,
                    title: item.title,
                    preview: item.body.length > 80
                        ? '${item.body.substring(0, 80)}...'
                        : item.body,
                    fullText: item.body,
                    timestamp: item.timeLabel,
                    ctaLabel: item.ctaLabel,
                    onCta: item.ctaRoute == null
                        ? null
                        : () => context.push(item.ctaRoute!),
                    onDismiss: () => cubit.dismiss(item.id),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Semana ───────────────────────────────────────────────────────────────────

class _SemanaSection extends StatelessWidget {
  final HomeData data;
  const _SemanaSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekNum = _isoWeekNumber(now);
    final monthAbbr = _monthAbbr(monday.month);
    final volumePct = data.plannedSessions == 0
        ? 0.0
        : (data.completedSessions / data.plannedSessions).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text('SEMANA', style: context.runninType.displaySm),
            ),
            const SizedBox(width: 8),
            AppTag(
              label: '${data.completedSessions}/${data.plannedSessions} FEITAS',
              color: palette.primary,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Sem $weekNum · $monthAbbr ${monday.day}-${sunday.day} · ${data.completedSessions}/${data.plannedSessions} sessoes · ${(volumePct * 100).round()}% volume',
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _WeekGrid(weekDays: data.weekDays),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'VOLUME',
              style: TextStyle(
                color: palette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08,
              ),
            ),
            const Spacer(),
            Text(
              '${data.weeklyDistanceKm.toStringAsFixed(1)} / ${(data.plannedSessions * 5.0).toStringAsFixed(0)} km',
              style: TextStyle(
                color: palette.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MiniProgressBar(value: volumePct, color: palette.primary),
        if (data.plannedSessions == 0) ...[
          const SizedBox(height: 20),
          AppPanel(
            padding: const EdgeInsets.all(17.7),
            color: palette.surfaceAlt,
            child: Text(
              data.plan == null
                  ? 'Nenhum plano ativo ainda. A semana fica pronta assim que voce gerar o primeiro plano.'
                  : 'O plano existe, mas esta semana nao tem sessoes distribuidas. Revise o plano em Treino.',
              style: TextStyle(color: palette.muted, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  int _isoWeekNumber(DateTime date) {
    final doy = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final dow = date.weekday;
    return ((doy - dow + 10) / 7).floor();
  }

  String _monthAbbr(int month) {
    const abbrs = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return abbrs[month];
  }
}

class _WeekGrid extends StatelessWidget {
  final List<WeekDayData> weekDays;
  const _WeekGrid({required this.weekDays});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: weekDays.map((day) {
        final isRest = day.session == null;
        final distLabel = day.session == null
            ? 'DESC'
            : _fmtDist(day.session!.distanceKm);

        return Expanded(
          child: Container(
             height: 100,
            margin: EdgeInsets.only(right: day.dayOfWeek == 7 ? 0 : 4),
            decoration: BoxDecoration(
              color: day.isToday ? palette.surfaceAlt : palette.surface,
              border: Border.all(
                color: day.isToday
                    ? palette.primary.withValues(alpha: 0.4)
                    : palette.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.shortName,
                  style: TextStyle(
                    color: day.isDone
                        ? palette.primary
                        : day.isToday
                        ? palette.secondary
                        : palette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 20),
                if (day.isDone)
                  Icon(Icons.check, size: 18, color: palette.primary)
                else if (isRest)
                  Text(
                    'DESC',
                    style: TextStyle(
                      color: palette.border,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Text(
                    day.session!.type.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      color: day.isToday ? palette.text : palette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  distLabel,
                  style: TextStyle(
                    color: isRest ? palette.border : palette.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (day.session?.targetPace != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    day.session!.targetPace!,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (day.isToday) ...[
                  const SizedBox(height: 20),
                  Text(
                    'HOJE',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtDist(double km) {
    if (km >= 1) {
      final dec = km == km.truncateToDouble() ? 0 : 1;
      return '${km.toStringAsFixed(dec)}K';
    }
    return '${(km * 1000).toStringAsFixed(0)}m';
  }
}

// ─── Coach AI Semanal ────────────────────────────────────────────────────────

class _CoachAiWeeklySummary extends StatelessWidget {
  final HomeData data;
  const _CoachAiWeeklySummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final planKm = _plannedWeeklyDistance(data);
    final completion = data.plannedSessions == 0
        ? 0.0
        : (data.completedSessions / data.plannedSessions).clamp(0.0, 1.0);
    final hasPlan = data.plan != null && data.plannedSessions > 0;
    final hasRuns = data.completedRuns.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'COACH.AI', style: context.runninType.displaySm),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          color: palette.surfaceAlt,
          borderColor: palette.secondary.withValues(alpha: 0.45),
          child: Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: palette.secondary, width: 1.735),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '> RESUMO SEMANAL',
                  style: context.runninType.labelCaps.copyWith(
                    color: palette.secondary,
                  ),
                ),
                const SizedBox(height: 20),
                _CoachSummaryBlock(
                  title: 'PROGRESSO',
                  body: hasPlan
                      ? '${data.completedSessions} de ${data.plannedSessions} sessoes concluidas. Volume registrado: ${data.weeklyDistanceKm.toStringAsFixed(1)} de ${planKm.toStringAsFixed(1)} km planejados.'
                      : 'Sem plano semanal ativo. Gere um plano para o coach acompanhar sessoes, descanso e volume.',
                ),
                const SizedBox(height: 20),
                _MiniProgressBar(value: completion, color: palette.primary),
                const SizedBox(height: 20),
                _CoachSummaryBlock(
                  title: 'PERFORMANCE',
                  body: hasRuns
                      ? 'Ultima corrida: ${(data.latestRun!.distanceM / 1000).toStringAsFixed(1)} km${data.latestRun!.avgPace == null ? '' : ' em ${data.latestRun!.avgPace}/km'}. O historico ja alimenta pace, streak e carga muscular.'
                      : 'Ainda nao ha corrida concluida. Depois da primeira sessao, este bloco mostra tendencia de pace, BPM e resposta ao treino.',
                ),
                const SizedBox(height: 20),
                _CoachSummaryBlock(
                  title: 'RECOMENDACAO',
                  body: _weeklyRecommendation(data),
                ),
                if (!hasPlan || !hasRuns) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!hasPlan)
                        OutlinedButton(
                          onPressed: () => context.push('/training'),
                          child: const Text('GERAR PLANO'),
                        ),
                      if (!hasRuns)
                        ElevatedButton(
                          onPressed: () => context.push('/prep'),
                          child: const Text('REGISTRAR CORRIDA'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachSummaryBlock extends StatelessWidget {
  final String title;
  final String body;

  const _CoachSummaryBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.runninType.labelCaps.copyWith(color: palette.primary),
        ),
        const SizedBox(height: 20),
        Text(
          body,
          style: TextStyle(
            color: palette.text.withValues(alpha: 0.86),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _MiniProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: LinearProgressIndicator(
        minHeight: 3,
        value: value.clamp(0.0, 1.0),
        backgroundColor: palette.border,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─── Performance ─────────────────────────────────────────────────────────────

class _PerformanceSection extends StatelessWidget {
  final HomeData data;
  const _PerformanceSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final runs = data.completedRuns;
    final run = data.latestRun;
    final avgPace = _averagePace(runs);
    final weeklyGoalKm = _plannedWeeklyDistance(data);
    final weeklyCompletion = weeklyGoalKm <= 0
        ? null
        : (data.weeklyDistanceKm / weeklyGoalKm).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'PERFORMANCE',
                style: context.runninType.displaySm,
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PACE TREND',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        avgPace ?? '--',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      Text(
                        avgPace != null
                            ? '/km · media das corridas'
                            : 'sem corridas suficientes',
                        style: TextStyle(color: palette.muted, fontSize: 9),
                      ),
                      const Spacer(),
                      if (avgPace == null)
                        TextButton(
                          onPressed: () => context.push('/prep'),
                          child: const Text('FAZER PRIMEIRA CORRIDA'),
                        )
                      else
                        Container(height: 3, color: palette.border),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARDIACO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        run?.avgBpm != null ? '${run!.avgBpm}' : '--',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        run?.avgBpm != null
                            ? 'bpm medio na ultima corrida'
                            : 'sem BPM registrado',
                        style: TextStyle(color: palette.muted, fontSize: 9),
                      ),
                      const Spacer(),
                      if (run?.avgBpm != null) ...[
                        Text(
                          'ZONA ESTIMADA',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${run!.avgBpm}',
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ZoneBars(avgBpm: run.avgBpm!),
                      ],
                      if (run?.avgBpm == null)
                        TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('REVISAR DADOS'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  color: palette.primary,
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BENCHMARK',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        weeklyCompletion == null
                            ? 'SEM BASE'
                            : '${(weeklyCompletion * 100).round()}%',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        weeklyCompletion == null
                            ? 'faltam km planejados para comparar'
                            : 'do volume previsto nesta semana',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (weeklyCompletion == null)
                        TextButton(
                          onPressed: () => context.push('/training'),
                          child: const Text('VER PLANO'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STREAK',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${data.streakDays}',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      Text(
                        'dias',
                        style: TextStyle(color: palette.muted, fontSize: 11),
                      ),
                      const Spacer(),
                      _MonthStats(data: data),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneBars extends StatelessWidget {
  final int avgBpm;
  const _ZoneBars({required this.avgBpm});

  @override
  Widget build(BuildContext context) {
    final zones = <Color>[
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.yellow.shade600,
      Colors.orange.shade500,
      Colors.red.shade500,
    ];
    final zone = avgBpm < 120
        ? 0
        : avgBpm < 140
        ? 1
        : avgBpm < 160
        ? 2
        : avgBpm < 175
        ? 3
        : 4;

    return Row(
      children: List.generate(5, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 4 ? 2 : 0),
            height: 5,
            color: i <= zone ? zones[i] : zones[i].withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

class _MonthStats extends StatelessWidget {
  final HomeData data;
  const _MonthStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final now = DateTime.now();
    final monthNames = [
      '',
      'JANEIRO',
      'FEVEREIRO',
      'MARCO',
      'ABRIL',
      'MAIO',
      'JUNHO',
      'JULHO',
      'AGOSTO',
      'SETEMBRO',
      'OUTUBRO',
      'NOVEMBRO',
      'DEZEMBRO',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthNames[now.month],
          style: TextStyle(
            color: palette.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.06,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('KM', style: TextStyle(color: palette.muted, fontSize: 9)),
            Text(
              data.weeklyDistanceKm.toStringAsFixed(1),
              style: TextStyle(
                color: palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Status Corporal ──────────────────────────────────────────────────────────

class _StatusCorporalSection extends StatefulWidget {
  final HomeData data;
  const _StatusCorporalSection({required this.data});

  @override
  State<_StatusCorporalSection> createState() => _StatusCorporalSectionState();
}

class _StatusCorporalSectionState extends State<_StatusCorporalSection> {
  double? _hydrationLoggedL;

  @override
  void initState() {
    super.initState();
    _reloadHydration();
  }

  void _reloadHydration() {
    _hydrationLoggedL = _hydrationIntakeLiters();
  }

  Future<void> _openHydrationSheet({required double goalLiters}) async {
    final currentLiters = _hydrationLoggedL ?? 0;
    final updatedLiters = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HydrationUpdateSheet(
        initialLiters: currentLiters,
        goalLiters: goalLiters,
      ),
    );
    if (updatedLiters == null) return;

    await _saveHydrationIntakeLiters(updatedLiters);
    if (!mounted) return;
    setState(() {
      _hydrationLoggedL = updatedLiters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final profile = widget.data.profile;
    final hasBpmData = _hasRealBpmData(widget.data);
    final hasSleepData = _hasRealSleepData(widget.data);
    final bmi = _calculateBmi(profile);
    final hasBodyData = bmi != null;
    final readinessScore = hasBodyData
        ? _readinessScore(widget.data, bmi)
        : null;
    final hydrationGoalL = _hydrationGoalLiters(profile);
    final hydrationLoggedL = _hydrationLoggedL;
    final hydrationPct = hydrationGoalL == null || hydrationLoggedL == null
        ? null
        : (hydrationLoggedL / hydrationGoalL).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'STATUS CORPORAL',
                style: context.runninType.displaySm,
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRONTIDAO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            readinessScore?.toString() ?? '--',
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' /100',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        hasBodyData
                            ? _readinessLabel(readinessScore!)
                            : 'Preencha peso, altura e idade para destravar',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      if (hasBodyData)
                        _MiniProgressBar(
                          value: readinessScore! / 100,
                          color: palette.secondary,
                        )
                      else
                        TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('PREENCHER DADOS'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SONO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        hasSleepData ? 'OK' : '--',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        profile?.hasWearable == true
                            ? 'Wearable informado, mas sem sono sincronizado'
                            : 'Sem origem de sono conectada',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/profile/edit'),
                        child: Text(
                          hasSleepData ? 'VER DETALHES' : 'REVISAR PERFIL',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARGA MUSCULAR',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _muscleLoadLabel(widget.data),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        hasBpmData
                            ? 'Baseado em corrida com BPM e volume da semana'
                            : 'Baseado em distancia e volume; sem BPM real ainda',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _CargaChip(
                            label: 'BAIXA',
                            active: _muscleLoadLabel(widget.data) == 'BAIXA',
                          ),
                          const SizedBox(width: 4),
                          _CargaChip(
                            label: 'MEDIA',
                            active: _muscleLoadLabel(widget.data) == 'MEDIA',
                          ),
                          const SizedBox(width: 4),
                          _CargaChip(
                            label: 'ALTA',
                            active: _muscleLoadLabel(widget.data) == 'ALTA',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(17.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HIDRATACAO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            hydrationLoggedL == null
                                ? '--'
                                : '${hydrationLoggedL.toStringAsFixed(1)}L',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            hydrationGoalL == null
                                ? ''
                                : ' /${hydrationGoalL.toStringAsFixed(1)}L',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        hydrationGoalL == null
                            ? 'Informe peso para calcular sua meta diaria'
                            : hydrationLoggedL == null
                            ? 'Sem ingestao de agua registrada no app'
                            : '${(hydrationPct! * 100).round()}% da meta diaria registrada',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      if (hydrationPct != null)
                        _MiniProgressBar(
                          value: hydrationPct,
                          color: palette.primary,
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: hydrationGoalL == null
                            ? () => context.push('/profile/edit')
                            : () => _openHydrationSheet(
                                goalLiters: hydrationGoalL,
                              ),
                        child: Text(
                          hydrationGoalL == null
                              ? 'INFORMAR PESO'
                              : hydrationLoggedL == null
                              ? 'REGISTRAR AGUA'
                              : 'ATUALIZAR AGUA',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HydrationUpdateSheet extends StatefulWidget {
  final double initialLiters;
  final double goalLiters;

  const _HydrationUpdateSheet({
    required this.initialLiters,
    required this.goalLiters,
  });

  @override
  State<_HydrationUpdateSheet> createState() => _HydrationUpdateSheetState();
}

class _HydrationUpdateSheetState extends State<_HydrationUpdateSheet> {
  static const List<int> _quickMlSteps = [200, 300, 500];
  static const double _deltaLiters = 0.1;
  late double _currentLiters;

  @override
  void initState() {
    super.initState();
    _currentLiters = widget.initialLiters;
  }

  void _changeBy(double liters) {
    setState(() {
      final next = _currentLiters + liters;
      _currentLiters = next < 0 ? 0 : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final pct = (_currentLiters / widget.goalLiters).clamp(0.0, 2.0);
    final overGoal = _currentLiters > widget.goalLiters;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: Container(
          padding: const EdgeInsets.all(17.7),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'HIDRATACAO DO DIA',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              Text(
                '${_currentLiters.toStringAsFixed(1)}L de ${widget.goalLiters.toStringAsFixed(1)}L',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct > 1 ? 1 : pct,
                  minHeight: 8,
                  backgroundColor: palette.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overGoal ? palette.secondary : palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeBy(-_deltaLiters),
                      icon: const Icon(Icons.remove),
                      label: const Text('-100ML'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeBy(_deltaLiters),
                      icon: const Icon(Icons.add),
                      label: const Text('+100ML'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickMlSteps
                    .map(
                      (ml) => ActionChip(
                        label: Text('+$ml ML'),
                        onPressed: () => _changeBy(ml / 1000),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_currentLiters),
                  child: const Text('SALVAR CONSUMO'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentLiters = 0),
                child: const Text('ZERAR HOJE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CargaChip extends StatelessWidget {
  final String label;
  final bool active;
  const _CargaChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? palette.secondary.withValues(alpha: 0.15)
              : palette.surface,
          border: Border.all(
            color: active ? palette.secondary : palette.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? palette.secondary : palette.muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─── Última Corrida ───────────────────────────────────────────────────────────

class _UltimaCorrida extends StatelessWidget {
  final Run? run;
  const _UltimaCorrida({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'ULTIMA CORRIDA',
                style: context.runninType.displaySm,
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (run == null)
          AppPanel(
            child: Text(
              'Nenhuma corrida concluida ainda. Assim que voce terminar a primeira, este painel mostrara pace, BPM e XP.',
              style: TextStyle(color: palette.muted, height: 1.5),
            ),
          )
        else
          _RunCard(run: run!),
      ],
    );
  }
}

String _formatKm(double km) {
  final dec = km == km.truncateToDouble() ? 0 : 1;
  return '${km.toStringAsFixed(dec)} km';
}

String? _averagePace(List<Run> runs) {
  final validRuns = runs
      .where((run) => run.distanceM > 0 && run.durationS > 0)
      .toList();
  if (validRuns.length < 2) {
    return validRuns.isEmpty ? null : validRuns.first.avgPace;
  }

  final totalDistanceKm = validRuns.fold<double>(
    0,
    (sum, run) => sum + (run.distanceM / 1000),
  );
  final totalDurationS = validRuns.fold<int>(
    0,
    (sum, run) => sum + run.durationS,
  );
  if (totalDistanceKm <= 0) return null;
  final secPerKm = totalDurationS / totalDistanceKm;
  final min = (secPerKm ~/ 60).toInt();
  final sec = (secPerKm % 60).round();
  return '$min:${sec.toString().padLeft(2, '0')}';
}

double _plannedWeeklyDistance(HomeData data) {
  return data.weekDays.fold<double>(
    0,
    (sum, day) => sum + (day.session?.distanceKm ?? 0),
  );
}

bool _hasRealBpmData(HomeData data) {
  return data.completedRuns.any((run) => run.avgBpm != null);
}

bool _hasRealSleepData(HomeData data) {
  return false;
}

String _weeklyRecommendation(HomeData data) {
  if (data.plan == null) {
    return 'Comece gerando um plano. A Home ja mostra os blocos vazios para voce saber quais dados vao aparecer depois.';
  }
  if (data.plannedSessions == 0) {
    return 'Revise o plano: nao ha sessoes nesta semana para o coach comparar volume, descanso e progresso.';
  }
  if (data.completedRuns.isEmpty) {
    return 'Faca a primeira corrida da semana em intensidade confortavel. Depois disso, o coach passa a comparar execucao e plano.';
  }
  if (data.completedSessions >= data.plannedSessions) {
    return 'Semana completa. Priorize recuperacao, hidratacao e sono antes do proximo bloco.';
  }
  if (data.todaySession != null) {
    return 'Ha treino planejado hoje. Mantenha ritmo controlado e ajuste por sensacao se houver fadiga acumulada.';
  }
  return 'Ainda ha sessoes pendentes na semana. Use os dias restantes com prioridade para consistencia e recuperacao.';
}

double? _parseDouble(String? raw) {
  if (raw == null) return null;
  final normalized = raw
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(normalized);
}

double? _calculateBmi(UserProfile? profile) {
  final weightKg = _parseDouble(profile?.weight);
  final heightCm = _parseDouble(profile?.height);
  if (weightKg == null || heightCm == null || heightCm <= 0) return null;
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

int _readinessScore(HomeData data, double bmi) {
  final latest = data.latestRun;
  var score = 55;
  if (data.todaySession != null) score += 10;
  if (data.streakDays > 0 && data.streakDays <= 4) score += 8;
  if (data.weeklyDistanceKm > 0) score += 8;
  if (latest?.avgBpm != null && latest!.avgBpm! < 165) score += 8;
  if (bmi >= 18.5 && bmi < 30) score += 6;
  return score.clamp(0, 100);
}

String _readinessLabel(int score) {
  if (score >= 75) return 'Base minima para treinar hoje';
  if (score >= 60) return 'Treino leve ou moderado recomendado';
  return 'Poucos dados ou recuperacao em observacao';
}

String _muscleLoadLabel(HomeData data) {
  final latestDistance = (data.latestRun?.distanceM ?? 0) / 1000;
  if (latestDistance >= 12 || data.weeklyDistanceKm >= 30) return 'ALTA';
  if (latestDistance >= 6 || data.weeklyDistanceKm >= 15) return 'MEDIA';
  return 'BAIXA';
}

double? _hydrationGoalLiters(UserProfile? profile) {
  final weightKg = _parseDouble(profile?.weight);
  if (weightKg == null) return null;
  return ((weightKg * 35) / 1000);
}

const _settingsBoxName = 'runnin_settings';
const _hydrationKeyPrefix = 'hydration_ml_';

String _hydrationDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$_hydrationKeyPrefix$year$month$day';
}

Box<dynamic>? _settingsBoxOrNull() {
  if (!Hive.isBoxOpen(_settingsBoxName)) return null;
  return Hive.box<dynamic>(_settingsBoxName);
}

double? _hydrationIntakeLiters() {
  final value = _settingsBoxOrNull()?.get(_hydrationDateKey(DateTime.now()));
  if (value is int) return value / 1000;
  if (value is double) return value / 1000;
  return null;
}

Future<void> _saveHydrationIntakeLiters(double liters) async {
  final box = _settingsBoxOrNull();
  if (box == null) return;

  final hydrationMl = (liters * 1000).round();
  await box.put(
    _hydrationDateKey(DateTime.now()),
    hydrationMl < 0 ? 0 : hydrationMl,
  );
}

class _RunCard extends StatelessWidget {
  final Run run;
  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final createdAt = DateTime.tryParse(run.createdAt);
    final dateLabel = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')} · ${run.type.toUpperCase()}'
        : run.type.toUpperCase();
    final distKm = (run.distanceM / 1000).toStringAsFixed(1);
    final duration = _fmtDuration(run.durationS);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'DURACAO',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.08,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${distKm}K', style: context.runninType.dataMd),
              Text(
                duration,
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _RunMetric(
                label: 'PACE',
                sub: '/km',
                value: run.avgPace ?? '--',
                accent: palette.secondary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'BPM',
                sub: 'avg',
                value: run.avgBpm?.toString() ?? '--',
                accent: palette.primary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'XP',
                sub: 'pts',
                value: run.xpEarned != null ? '+${run.xpEarned}' : '--',
                accent: palette.primary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'STREAK',
                sub: 'dias',
                value: run.status == 'completed' ? '1+' : '--',
                accent: palette.text,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(17.7),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: palette.primary, width: 3),
              ),
            ),
            child: Text(
              'Resumo real da corrida concluida. O relatorio tecnico completo fica na aba de feedback do treino.',
              style: TextStyle(
                color: palette.text.withValues(alpha: 0.8),
                height: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('VER DETALHES'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('COMPARTILHAR →'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _RunMetric extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  final Color accent;
  const _RunMetric({
    required this.label,
    required this.sub,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(sub, style: TextStyle(color: palette.muted, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Skin Section ────────────────────────────────────────────────────────────

class _SkinSection extends StatelessWidget {
  const _SkinSection();

  static const _skins = [
    RunninSkin.sangue,
    RunninSkin.magenta,
    RunninSkin.volt,
    RunninSkin.artico,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'SKIN',
                style: context.runninType.displaySm,
              ),
              TextSpan(
                text: ' 01',
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Escolha a paleta de cores do app',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, child) {
            final currentSkin = themeController.skin;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PaletteCard(
                        skin: _skins[0],
                        isActive: currentSkin == _skins[0],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PaletteCard(
                        skin: _skins[1],
                        isActive: currentSkin == _skins[1],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PaletteCard(
                        skin: _skins[2],
                        isActive: currentSkin == _skins[2],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PaletteCard(
                        skin: _skins[3],
                        isActive: currentSkin == _skins[3],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final RunninSkin skin;
  final bool isActive;

  const _PaletteCard({required this.skin, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final skinPalette = skin.palette;
    final textAlpha = isActive ? 1.0 : 0.6;

    return GestureDetector(
      onTap: () => themeController.setSkin(skin),
      child: Container(
        height: 103,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.text.withValues(alpha: 0.03),
          border: Border.all(
            color: isActive ? palette.primary : palette.border,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: skinPalette.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: skinPalette.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                if (isActive)
                  Text(
                    'ATIVA',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                      letterSpacing: 0.9,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              skinPalette.label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.text.withValues(alpha: textAlpha),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: Row(
                children: skinPalette.previewBars
                    .map(
                      (color) => Expanded(
                        child: Container(height: 4, color: color),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu ─────────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'MENU',
                style: context.runninType.displaySm,
              ),
              TextSpan(
                text: ' 02',
                style: TextStyle(
                  color: context.runninPalette.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MenuItem(
          icon: Icons.emoji_events_outlined,
          title: 'GAMIFICAÇÃO',
          subtitle: 'Badges, XP, Streak',
          route: '/gamification',
        ),
        const SizedBox(height: 4),
        _MenuItem(
          icon: Icons.favorite_border,
          title: 'SAÚDE',
          subtitle: 'BPM, Zonas, Wearable',
          route: '/health',
        ),
        const SizedBox(height: 4),
        _MenuItem(
          icon: Icons.settings_outlined,
          title: 'AJUSTES',
          subtitle: 'Coach, Alertas, Unidades',
          route: '/settings',
        ),
        const SizedBox(height: 4),
        _MenuItem(
          icon: Icons.diamond_outlined,
          title: 'ASSINATURA',
          subtitle: 'Premium',
          route: '/subscription',
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return InkWell(
      onTap: () => context.push(route),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: palette.text.withValues(alpha: 0.03),
          border: Border.all(
            color: palette.text.withValues(alpha: 0.08),
            width: 1.735,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.text.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: palette.text.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '↗',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: palette.text.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            color: palette.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: palette.muted)),
          const SizedBox(height: 20),
          TextButton(onPressed: onRetry, child: const Text('TENTAR NOVAMENTE')),
        ],
      ),
    );
  }
}
