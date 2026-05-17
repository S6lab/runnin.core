import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/home/domain/use_cases/get_home_data_use_case.dart';
import 'package:runnin/features/home/presentation/cubit/home_cubit.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';
import 'package:runnin/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/notification_card.dart';
import 'package:runnin/shared/widgets/section_heading.dart';
import 'package:runnin/shared/widgets/week_grid.dart' as wg;

// Helper functions for greeting and date formatting (used by both _HeroSection and _CyberStatusBar)
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
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.px20, AppSpacing.px20, AppSpacing.px20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(profileName: state is HomeLoaded ? state.data.profile?.name : null),
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
                     // B1 SUP-405 / SUP-598 Hero section — full-bleed area
                     ///Hero implements: greeting, date, session info, map placeholder with vector graphics hint,
                     //12 stat icons, and coach.ai brief. Real map asset from Figma pending.
                     _HeroSection(data: state.data),
                    const SizedBox(height: 20),
                    if (!(state.data.profile?.premium ?? false)) ...[
                      _PremiumUpsellBanner(),
                      const SizedBox(height: 20),
                    ],
                    // NOTE: _UserInfoCards (peso/altura/idade/freq) and
                    // _SkinSection used to live here as a dashboard-style
                    // layout. They are PERFIL-owned sections and were
                    // duplicates of identically-named private widgets in
                    // account_page.dart. Removed from HOME to fix the
                    // cross-tab content leak reported by the user.
                    // B2 SUP-406 Section 1 — Coach Brief + INICIAR
                    _IniciarSessaoButton(data: state.data),
                    const SizedBox(height: 20),
                    // B3 SUP-407 Section 2 — Notificações
                    const _CoachNotifications(),
                    const SizedBox(height: 20),
                    // B4 SUP-408 Section 3 — Semana
                    _SemanaSection(data: state.data),
                    const SizedBox(height: 20),
                    // B5 SUP-409 Section 4 — Performance
                    _PerformanceSection(data: state.data),
                    const SizedBox(height: 20),
                    // B6 SUP-410 Section 5 — Coach Resumo Semanal
                     _CoachAiWeeklySummary(data: state.data),
                     const SizedBox(height: 20),
                     // B7 SUP-411 Section 6 — Status Corporal (REAL)
                     ///status corporal implements all 4 metrics with real data: Prontidão, Sono, Carga Muscular, Hidratação
                     _StatusCorporalSection(data: state.data),
                    const SizedBox(height: 20),
                    // B8 SUP-412 Section 7 — Última Corrida
                    _UltimaCorrida(run: state.data.latestRun),
                    const SizedBox(height: 20),
                    // _MenuSection removed — that menu (GAMIFICAÇÃO /
                    // SAÚDE / AJUSTES / ASSINATURA) is PERFIL-owned and
                    // duplicated PERFIL's _MenuSection. See PERFIL tab.
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
  final String? profileName;
  const _HomeHeader({this.profileName});

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
                fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.w700, // exceção: .AI é bold
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Analytics destacado: chip com borda da skin (primary) +
            // ícone maior. Era um ícone sem label perdido entre outros.
            InkWell(
              onTap: () => context.push('/dashboard'),
              borderRadius: BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.10),
                  border: Border.all(color: palette.primary, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 18, color: palette.primary),
                    const SizedBox(width: 6),
                    Text(
                      'ANALYTICS',
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            InkWell(
              onTap: () => context.push('/profile'),
              borderRadius: BorderRadius.zero,
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
                          fontWeight: FontWeight.w500,
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
    final name = (profileName ?? user?.displayName ?? user?.email ?? '').trim();
    if (name.isEmpty) return 'A';
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
    final profileName = data.profile?.name.trim();
    final fallbackName = user?.displayName?.split(' ').firstOrNull;
    final firstName = (profileName != null && profileName.isNotEmpty)
        ? profileName.split(' ').first
        : (fallbackName ?? 'ATLETA');
    final dateLabel = _formatDate(now);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: palette.text.withValues(alpha: 0.06),
            width: 1.041,
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
              Expanded(
                child: Text(
                  '$dateLabel — $greeting, ${firstName.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.text.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 0.96,
                  ),
                  overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.zero,
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

    // _CyberTodayCard movido pra dentro do _HeroSection (evita duplicação).
    // Aqui fica só Coach AI + CTA INICIAR.
    final isPremium = data.profile?.premium ?? false;
    return _CoachMessageCard(
      palette: palette,
      message: coachMessage,
      ctaLabel: isPremium
          ? (session != null ? 'INICIAR SESSAO ↗' : 'INICIAR CORRIDA LIVRE ↗')
          : 'INICIAR CORRIDA LIVRE ↗',
      onCta: () async {
        // Sem premium: corrida livre OK; sessão guiada AI = paywall
        if (!isPremium && session != null) {
          context.push('/paywall?next=/home');
          return;
        }
        // Briefing do Coach aparece UMA vez, antes do PREP, na primeira corrida
        // após o plano ter sido gerado.
        final introSeen = data.profile?.coachIntroSeen ?? false;
        if (!context.mounted) return;
        context.push(introSeen ? '/prep' : '/coach-intro');
      },
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
               left: BorderSide(color: palette.secondary, width: 1.041),
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
                fontWeight: FontWeight.w500,
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
          Text(
            'HOJE',
            style: GoogleFonts.jetBrainsMono(
              color: palette.text,
              fontSize: 40,
              fontWeight: FontWeight.w500,
              letterSpacing: -2,
              height: 0.88,
            ),
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
                    fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w500,
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
                                  color: palette.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
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
                                  fontWeight: FontWeight.w500,
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
        return _NotificationsHub(items: state.items);
      },
    );
  }
}

/// Central de notificações da home — dropdown colapsável, 5 grupos fixos
/// na ordem definida pelo board (SUP).
///
/// Cada grupo lê do mesmo NotificationsCubit (wired) e filtra por tipo:
/// - Hidratação      → type 'hidratacao' (+ ação especial: registrar copo)
/// - Preparo nutric. → type 'preparo_nutricional'
/// - Sono+performance→ types 'sono_performance' + 'bpm_real'
/// - Coach (alertas) → types 'melhor_horario' + 'checklist_pre_easy_run'
/// - Outras          → demais types ('fechamento_mensal' etc)
class _NotificationsHub extends StatefulWidget {
  final List<AppNotification> items;
  const _NotificationsHub({required this.items});

  @override
  State<_NotificationsHub> createState() => _NotificationsHubState();
}

class _NotificationsHubState extends State<_NotificationsHub> {
  // Apenas a primeira (hidratação) começa aberta; demais colapsadas.
  final Set<int> _expanded = {0};

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final hidratacao = widget.items.where((n) => n.type == 'hidratacao').toList();
    final nutricional = widget.items.where((n) => n.type == 'preparo_nutricional').toList();
    final sonoPerf = widget.items.where((n) => n.type == 'sono_performance' || n.type == 'bpm_real').toList();
    final coachMsgs = widget.items.where((n) => n.type == 'melhor_horario' || n.type == 'checklist_pre_easy_run').toList();
    final outras = widget.items.where((n) {
      const claimed = {'hidratacao', 'preparo_nutricional', 'sono_performance', 'bpm_real', 'melhor_horario', 'checklist_pre_easy_run'};
      return !claimed.contains(n.type);
    }).toList();

    final groups = <_NotifGroup>[
      _NotifGroup(
        label: 'HIDRATAÇÃO',
        icon: Icons.water_drop_outlined,
        accent: const Color(0xFF4FB3F0),
        items: hidratacao,
      ),
      _NotifGroup(
        label: 'PREPARO NUTRICIONAL',
        icon: Icons.restaurant_outlined,
        accent: const Color(0xFFFFC857),
        items: nutricional,
      ),
      _NotifGroup(
        label: 'SONO → PERFORMANCE',
        icon: Icons.bedtime_outlined,
        accent: const Color(0xFF6E8AFA),
        items: sonoPerf,
      ),
      _NotifGroup(
        label: 'MENSAGENS DO COACH',
        icon: Icons.chat_bubble_outline,
        accent: const Color(0xFFE85D2A),
        items: coachMsgs,
      ),
      _NotifGroup(
        label: 'OUTRAS',
        icon: Icons.inbox_outlined,
        accent: const Color(0xFFB37BFA),
        items: outras,
      ),
    ];

    final totalCount = widget.items.length;
    final cubit = context.read<NotificationsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          label: 'CENTRAL DE NOTIFICAÇÕES',
          dotColor: palette.primary,
          badge: '$totalCount',
          action: totalCount > 0 ? 'LIMPAR' : null,
          onAction: totalCount > 0 ? cubit.clear : null,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border, width: 1.041),
          ),
          child: Column(
            children: [
              for (int i = 0; i < groups.length; i++) ...[
                if (i > 0) Divider(height: 1, color: palette.border),
                _NotifGroupTile(
                  group: groups[i],
                  expanded: _expanded.contains(i),
                  onToggle: () => setState(() {
                    if (_expanded.contains(i)) {
                      _expanded.remove(i);
                    } else {
                      _expanded.add(i);
                    }
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _NotifSpecial { none, hydrationLog }

class _NotifGroup {
  final String label;
  final IconData icon;
  final Color accent;
  final List<AppNotification> items;
  final _NotifSpecial special;
  const _NotifGroup({
    required this.label,
    required this.icon,
    required this.accent,
    required this.items,
    this.special = _NotifSpecial.none,
  });
}

class _NotifGroupTile extends StatelessWidget {
  final _NotifGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  const _NotifGroupTile({
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final count = group.items.length;
    final hasContent = count > 0 || group.special != _NotifSpecial.none;

    return Column(
      children: [
        InkWell(
          onTap: hasContent ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: group.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Icon(group.icon, size: 18, color: palette.text.withValues(alpha: 0.75)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: group.accent.withValues(alpha: 0.18),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: group.accent,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    color: hasContent ? palette.text.withValues(alpha: 0.6) : palette.text.withValues(alpha: 0.2),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(38, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in group.items) ...[
                        _NotifItemRow(notification: n, accent: group.accent),
                        const SizedBox(height: 8),
                      ],
                      if (group.special == _NotifSpecial.hydrationLog) _HydrationLogger(accent: group.accent),
                      if (group.items.isEmpty && group.special == _NotifSpecial.none)
                        Text(
                          'Sem alertas neste grupo agora.',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: palette.text.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NotifItemRow extends StatelessWidget {
  final AppNotification notification;
  final Color accent;
  const _NotifItemRow({required this.notification, required this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return GestureDetector(
      onTap: notification.ctaRoute == null ? null : () => context.push(notification.ctaRoute!),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (notification.timeLabel != null)
                  Text(
                    notification.timeLabel!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: palette.muted,
                      letterSpacing: 0.6,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notification.body,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: palette.text.withValues(alpha: 0.7),
                height: 1.55,
              ),
            ),
            if (notification.ctaLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                '${notification.ctaLabel!} →',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: accent,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HydrationLogger extends StatefulWidget {
  final Color accent;
  const _HydrationLogger({required this.accent});

  @override
  State<_HydrationLogger> createState() => _HydrationLoggerState();
}

class _HydrationLoggerState extends State<_HydrationLogger> {
  static const _hydrationBoxName = 'runnin_settings';
  static const _hydrationKey = 'hydration_ml_today';
  static const _hydrationDateKey = 'hydration_date';
  static const _defaultGoalMl = 2000;

  int _todayMl = 0;
  int? _goalMl;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGoal();
  }

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_hydrationBoxName)) return Hive.box<dynamic>(_hydrationBoxName);
    return Hive.openBox<dynamic>(_hydrationBoxName);
  }

  Future<void> _load() async {
    final b = await _box();
    final storedDate = b.get(_hydrationDateKey) as String?;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (storedDate != today) {
      await b.put(_hydrationDateKey, today);
      await b.put(_hydrationKey, 0);
    }
    if (mounted) setState(() => _todayMl = (b.get(_hydrationKey) as int?) ?? 0);
  }

  Future<void> _loadGoal() async {
    try {
      final profile = await UserRemoteDatasource().getMe();
      final weightStr = profile?.weight?.trim();
      if (weightStr == null || weightStr.isEmpty) return;
      final weightKg = double.tryParse(weightStr.replaceAll(',', '.'));
      if (weightKg == null || weightKg <= 0) return;
      if (mounted) setState(() => _goalMl = (weightKg * 35).round());
    } catch (_) {}
  }

  Future<void> _add(int ml) async {
    final b = await _box();
    final newTotal = _todayMl + ml;
    await b.put(_hydrationKey, newTotal);
    if (mounted) setState(() => _todayMl = newTotal);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final goalMl = _goalMl ?? _defaultGoalMl;
    final progress = (_todayMl / goalMl).clamp(0.0, 1.0);
    final isGoalReached = _todayMl >= goalMl;
    final goalLiters = (goalMl / 1000).toStringAsFixed(goalMl % 1000 == 0 ? 1 : 2);
    final currentLiters = (_todayMl / 1000).toStringAsFixed(2);
    final goalSourceLabel = _goalMl == null
        ? 'meta 2L (cadastre seu peso para meta personalizada)'
        : 'meta ${goalLiters}L (35ml/kg)';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTRAR HOJE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: palette.text,
                  letterSpacing: 0.8,
                ),
              ),
              if (isGoalReached)
                Text(
                  '✓ META',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: widget.accent,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${currentLiters}L / ${goalLiters}L',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            goalSourceLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: palette.text.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          _MiniProgressBar(value: progress, color: widget.accent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final ml in const [200, 350, 500, 750])
                OutlinedButton(
                  onPressed: () => _add(ml),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    '+${ml}ml',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachNotificationsList extends StatelessWidget {
  final List<AppNotification> items;
  const _CoachNotificationsList({required this.items});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();

    // SUP-407 (HOME-B3): Section 2 — COACH.AI > NOTIFICAÇÕES
    // Uses SectionHeading + 5-color cycling NotificationCard per HOME.md §02.
    const accents = [
      NotificationAccent.cyan,
      NotificationAccent.yellow,
      NotificationAccent.blue,
      NotificationAccent.orange,
      NotificationAccent.purple,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          label: 'COACH.AI > NOTIFICAÇÕES',
          dotColor: context.runninPalette.primary,
          badge: '${items.length}',
          action: 'LIMPAR',
          onAction: cubit.clear,
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          NotificationCard(
            icon: items[i].icon,
            title: items[i].title.toUpperCase(),
            subtitle: items[i].body.length > 60
                ? '${items[i].body.substring(0, 60)}…'
                : items[i].body,
            timestamp: items[i].timeLabel,
            borderColor: accents[i % accents.length],
            onTap: items[i].ctaRoute == null
                ? null
                : () => context.push(items[i].ctaRoute!),
          ),
        ],
        const SizedBox(height: 6),
        const _ExpandableCoachAICard(),
      ],
    );
  }
}

// ─── Expandable Coach.AI Card ─────────────────────────────────────────────────

class _ExpandableCoachAICard extends StatefulWidget {
  const _ExpandableCoachAICard();

  @override
  State<_ExpandableCoachAICard> createState() => _ExpandableCoachAICardState();
}

class _ExpandableCoachAICardState extends State<_ExpandableCoachAICard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(17.74, 14, 16, 14),
          decoration: BoxDecoration(
            color: FigmaColors.surfaceCardOrange,
            border: Border(
              left: BorderSide(
                color: context.runninPalette.secondary,
                width: FigmaDimensions.borderUniversal,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COACH.AI > FECHAMENTO MENSAL',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            height: 16.5 / 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w500,
                            color: context.runninPalette.secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Como foi o seu mês de treino?',
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            height: 16.5 / 11,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      '▼',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        height: 1,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 14),
                Text(
                  'Você completou ${DateTime.now().month == 1 ? 'Janeiro' : _monthName(DateTime.now().month - 1)}. O Coach.AI preparou um resumo com suas métricas, zonas de esforço e evolução. Deseja ver o fechamento completo?',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 18 / 11,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          color: context.runninPalette.primary,
                          child: Text(
                            'VER RESUMO',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.1,
                              color: FigmaColors.bgBase,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = false),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: FigmaColors.textSecondary,
                            width: FigmaDimensions.borderUniversal,
                          ),
                        ),
                        child: Text(
                          'IGNORAR',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.1,
                            color: FigmaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return names[month.clamp(1, 12)];
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

    // SUP-408 (HOME-B4): SEMANA heading with cyan superscript "02"
    // per HOME.md §03 + existing subtitle and weekly grid.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BigHeading(
          'SEMANA',
          '02',
          subtitle:
              'Sem $weekNum · $monthAbbr ${monday.day}-${sunday.day} · ${data.completedSessions}/${data.plannedSessions} sessoes · ${(volumePct * 100).round()}% volume',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AppTag(
              label: '${data.completedSessions}/${data.plannedSessions} FEITAS',
              color: palette.primary,
            ),
          ],
        ),
        const SizedBox(height: 20),
        // SUP-404 [HOME-A6]: shared WeekGrid component renders the 7-day
        // grid per Figma spec (header 37.7, body 110.4, with status icon +
        // type + distance + pace). Domain WeekDayData maps to widget cells.
        wg.WeekGrid(
          cells: [
            for (final d in data.weekDays)
              wg.WeekDayCellData(
                label: d.shortName,
                status: d.session == null
                    ? wg.WeekDayCellStatus.rest
                    : d.isToday
                        ? wg.WeekDayCellStatus.today
                        : d.isDone
                            ? wg.WeekDayCellStatus.done
                            : wg.WeekDayCellStatus.planned,
                type: d.session == null
                    ? null
                    : d.session!.type.length >= 3
                        ? d.session!.type.substring(0, 3).toUpperCase()
                        : d.session!.type.toUpperCase(),
                distance: d.session == null
                    ? null
                    : '${d.session!.distanceKm.toStringAsFixed(d.session!.distanceKm == d.session!.distanceKm.truncateToDouble() ? 0 : 1)}K',
                paceOrDuration: d.session?.targetPace,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'VOLUME',
              style: TextStyle(
                color: palette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.08,
              ),
            ),
            const Spacer(),
            Text(
              '${data.weeklyDistanceKm.toStringAsFixed(1)} / ${(data.plannedSessions * 5.0).toStringAsFixed(0)} km',
              style: TextStyle(
                color: palette.text,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MiniProgressBar(value: volumePct, color: palette.primary),
        if (data.plannedSessions == 0) ...[
          const SizedBox(height: 16),
          Text(
            data.plan == null
                ? 'Nenhum plano ativo ainda. A semana fica pronta assim que voce gerar o primeiro plano.'
                : 'O plano existe, mas esta semana nao tem sessoes distribuidas. Revise o plano em Treino.',
            style: TextStyle(color: palette.muted, height: 1.5, fontSize: 12),
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

    // SUP-410 (HOME-B6): Coach.AI Resumo Semanal — replaces the previous
    // "COACH.AI ᴬᴵ" heading with a SectionHeading using the orange dot
    // pattern per HOME.md §05. Inner left-border container keeps its
    // existing 3-sub-block layout (PROGRESSO / PERFORMANCE / RECOMENDACAO).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          label: '> RESUMO SEMANAL · SEM 2',
          dotColor: context.runninPalette.secondary,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: palette.secondary, width: 1.041),
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
                // Botão "GERAR PLANO" removido — geração de plano é restrita
                // (cooldown 1×/semana). Resumo semanal só mostra estado, sem
                // CTA de regerar. Para iniciar corrida ainda mostramos atalho.
                if (!hasRuns) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.push('/prep'),
                    child: const Text('REGISTRAR CORRIDA'),
                  ),
                ],
              ],
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

    // SUP-409 (HOME-B5): PERFORMANCE heading with cyan superscript "04"
    // per HOME.md §04. Inline metric cards stay; full migration to
    // MetricCard component is a follow-up (deeper refactor would touch
    // ~240 lines of grid layout currently inline here).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BigHeading('PERFORMANCE', '03'),
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
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        avgPace ?? '--',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        run?.avgBpm != null ? '${run!.avgBpm}' : '--',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${run!.avgBpm}',
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${data.streakDays}',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
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
            fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w500,
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

    // SUP-411 (HOME-B7): STATUS CORPORAL — 2×2 MetricCard grid per HOME.md §06.
    final muscleLoad = _muscleLoadLabel(widget.data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BigHeading('STATUS CORPORAL', '04'),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  label: 'PRONTIDAO',
                  value: readinessScore?.toString() ?? '--',
                  unit: '/100',
                  valueColor: context.runninPalette.primary,
                  sub: hasBodyData
                      ? _readinessLabel(readinessScore!)
                      : 'Preencha peso, altura e idade',
                  chart: hasBodyData
                      ? _MiniProgressBar(
                          value: readinessScore! / 100,
                          color: context.runninPalette.primary,
                        )
                      : TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('PREENCHER DADOS'),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'SONO',
                  value: hasSleepData ? 'OK' : '--',
                  valueColor: FigmaColors.textPrimary,
                  sub: profile?.hasWearable == true
                      ? 'Wearable sem sono sincronizado'
                      : 'Sem origem de sono conectada',
                  chart: TextButton(
                    onPressed: () => context.push('/profile/edit'),
                    child: Text(hasSleepData ? 'VER DETALHES' : 'REVISAR PERFIL'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  label: 'CARGA MUSCULAR',
                  value: muscleLoad,
                  valueColor: context.runninPalette.primary,
                  sub: hasBpmData
                      ? 'Com BPM e volume da semana'
                      : 'Sem BPM real; por distancia/volume',
                  chart: Row(
                    children: [
                      _CargaChip(label: 'BAIXA', active: muscleLoad == 'BAIXA'),
                      const SizedBox(width: 4),
                      _CargaChip(label: 'MEDIA', active: muscleLoad == 'MEDIA'),
                      const SizedBox(width: 4),
                      _CargaChip(label: 'ALTA', active: muscleLoad == 'ALTA'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'HIDRATACAO',
                  value: hydrationLoggedL == null
                      ? '--'
                      : '${hydrationLoggedL.toStringAsFixed(1)}L',
                  unit: hydrationGoalL == null
                      ? null
                      : '/${hydrationGoalL.toStringAsFixed(1)}L',
                  valueColor: context.runninPalette.primary,
                  sub: hydrationGoalL == null
                      ? 'Informe peso para calcular meta'
                      : hydrationLoggedL == null
                          ? 'Sem ingestao registrada'
                          : '${(hydrationPct! * 100).round()}% da meta diaria',
                  chart: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hydrationPct != null) ...[
                        _MiniProgressBar(
                          value: hydrationPct,
                          color: context.runninPalette.primary,
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton(
                        onPressed: hydrationGoalL == null
                            ? () => context.push('/profile/edit')
                            : () => _openHydrationSheet(goalLiters: hydrationGoalL),
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
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'HIDRATACAO DO DIA',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Text(
                '${_currentLiters.toStringAsFixed(1)}L de ${widget.goalLiters.toStringAsFixed(1)}L',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.zero,
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
            fontWeight: FontWeight.w500,
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
        const _BigHeading('ÚLTIMA CORRIDA', '05'),
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
    final createdAt = DateTime.tryParse(run.createdAt);
    final dateLabel = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}.${_monthAbbr(createdAt.month)} · ${run.type.toUpperCase()}'
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
              Expanded(
                child: Text(
                  dateLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.1,
                    color: context.runninPalette.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'DURAÇÃO',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.1,
                  color: FigmaColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${distKm}K',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textPrimary,
                ),
              ),
              Text(
                duration,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: context.runninPalette.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/share', extra: {'runId': run.id}),
            child: Container(
              width: double.infinity,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: context.runninPalette.primary, width: 1.041),
              ),
              child: Text(
                'COMPARTILHAR',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                  color: context.runninPalette.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthAbbr(int month) {
    const months = ['JAN','FEV','MAR','ABR','MAI','JUN','JUL','AGO','SET','OUT','NOV','DEZ'];
    return months[month - 1];
  }

  String _fmtDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

// ─── Helpers added with HOME-B series (SUP-405..SUP-412) ─────────────────────

/// Bold-22 + cyan-superscript section heading per HOME §03–§07
/// (e.g. "SEMANA" + small "02"). The dot-prefixed variant
/// (Coach.AI sections) lives in [SectionHeading].
class _BigHeading extends StatelessWidget {
  // `index` mantido na assinatura por compat com call sites; ignorado no
  // render (usuário pediu pra remover as marcações 01/02 dos headers).
  const _BigHeading(this.label, this.index, {this.subtitle});

  final String label;
  final String index;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            height: 24.2 / 22,
            letterSpacing: -0.44,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              height: 18 / 12,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Hero section — full-bleed map background with today's session data.
/// Implements: greeting, date, session badge, vector graphics hint,
//12 stat icons with real data from plan. Real map image pending Figma export.
/// Per HOME spec §01, this section spans ~490px and contains user profile stats.
class _HeroSection extends StatelessWidget {
  final HomeData data;
  const _HeroSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final profileName = data.profile?.name.trim();
    final fallbackName = user?.displayName?.split(' ').firstOrNull;
    final firstName = (profileName != null && profileName.isNotEmpty)
        ? profileName.split(' ').first
        : (fallbackName ?? 'ATLETA');
    final dateLabel = _formatDate(now);
    
    // Today's session information
    final session = data.todaySession;
    final sessionInfo = session == null
        ? 'Nenhuma sessao planejada para hoje'
        : '${session.type.toUpperCase()} • ${session.targetPace ?? 'livre'}';

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final heroAsset = dayOfYear.isEven
        ? 'assets/img/hero/runner_1.png'
        : 'assets/img/hero/runner_2.png';

    final weekdayLabel = _weekdayLabel(now.weekday).toUpperCase();
    final weekNumber = _isoWeekNumber(now);
    final sessionType = (session?.type ?? 'LIVRE').toUpperCase();
    final distanceLabel = session != null
        ? '${session.distanceKm.toStringAsFixed(session.distanceKm % 1 == 0 ? 0 : 1)}K'
        : '—';
    final paceLabel = session?.targetPace ?? '—:—';
    final etaLabel = session != null
        ? '~${(session.distanceKm * _paceSecPerKm(session.targetPace) / 60).round()}min'
        : '';
    // Session ordinal: # sessões já completadas + 1 (a de hoje)
    final sessionOrdinal = (data.completedSessions + 1).toString().padLeft(2, '0');

    return Container(
      height: 540,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        image: DecorationImage(
          image: AssetImage(heroAsset),
          fit: BoxFit.cover,
          onError: (e, _) {
            debugPrint('HERO image error: $e');
          },
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Stack(
        children: [
          // Vinheta sutil pra texto não competir com a foto
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            // Stack expandido, conteúdo cobre todo o hero

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: bullet ciano + data — GREETING
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${dateLabel.toUpperCase()} — $greeting, ${firstName.toUpperCase()}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Chips: WATCH + AUDIO
                Row(
                  children: [
                    _HeroChip(
                      icon: Icons.watch_outlined,
                      label: 'WATCH',
                      dotColor: palette.primary,
                    ),
                    const SizedBox(width: 10),
                    _HeroChip(
                      icon: Icons.headphones_outlined,
                      label: 'AUDIO',
                      dotColor: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // HOJE + ordinal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOJE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 64,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        sessionOrdinal,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // EASY RUN pill + dia · semana
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: palette.primary,
                      child: Text(
                        sessionType,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$weekdayLabel · SEM $weekNumber',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Stats: 5K + 6:30/km + ~32min
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      distanceLabel,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 64,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: paceLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFE85D2A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: '/km',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFE85D2A).withValues(alpha: 0.85),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (etaLabel.isNotEmpty)
                            Text(
                              etaLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 0.6,
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
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color dotColor;

  const _HeroChip({required this.icon, required this.label, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:    return 'segunda';
    case DateTime.tuesday:   return 'terca';
    case DateTime.wednesday: return 'quarta';
    case DateTime.thursday:  return 'quinta';
    case DateTime.friday:    return 'sexta';
    case DateTime.saturday:  return 'sabado';
    case DateTime.sunday:    return 'domingo';
    default: return '';
  }
}

int _isoWeekNumber(DateTime date) {
  final firstDay = DateTime(date.year, 1, 1);
  final dayOfYear = date.difference(firstDay).inDays + 1;
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

double _paceSecPerKm(String? pace) {
  if (pace == null) return 360; // 6:00/km default
  final parts = pace.split(':');
  if (parts.length != 2) return 360;
  final m = int.tryParse(parts[0]) ?? 6;
  final s = int.tryParse(parts[1]) ?? 0;
  return (m * 60 + s).toDouble();
}

class _HeroStatIcon extends StatelessWidget {
  final int index;
  const _HeroStatIcon({required this.index});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    
    // Mock icons for 12 icon layout per Figma spec
    final icons = [
      Icons.watch_outlined,
      Icons.brightness_3_outlined,
      Icons.water_drop_outlined,
      Icons.directions_run_outlined,
      Icons.speed_outlined,
      Icons.heart_broken_outlined,
      Icons.blur_circular_outlined,
      Icons.access_time_outlined,
      Icons.map_outlined,
      Icons.location_on_outlined,
      Icons.brightness_high_outlined,
      Icons.wb_sunny_outlined,
    ];
    
    return Icon(
      icons[index % icons.length],
      size: 18,
      color: palette.text.withValues(alpha: 0.5),
    );
  }
}

class _PremiumUpsellBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return GestureDetector(
      onTap: () => context.push('/paywall?next=/home'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.08),
          border: Border.all(color: palette.primary, width: 1.041),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_outlined, color: context.runninPalette.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COACH AI PREMIUM',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: palette.primary, letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plano personalizado, coach ao vivo e integração com wearable. R\$ 19,90/mês.',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w400,
                      color: palette.text.withValues(alpha: 0.75),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: palette.text.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

