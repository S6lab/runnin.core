import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/audio/audio_route_service.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/bpm_polling_service.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/home/domain/use_cases/get_home_data_use_case.dart';
import 'package:runnin/features/location_weather/data/location_weather_controller.dart';
import 'package:runnin/features/home/presentation/cubit/home_cubit.dart';
import 'package:runnin/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/subscriptions/presentation/widgets/premium_locked_card.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/section_heading.dart';
import 'package:runnin/shared/widgets/week_grid.dart' as wg;

/// Key global do _StatusCorporalSection — usado pelo _NotifItemRow
/// pra scroll auto quando o user clica na notificação de hidratação.
final GlobalKey statusCorporalSectionKey = GlobalKey();

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
    // NotificationsCubit vem do MainLayout (shell) — compartilhado com
    // /notifications pra badge e lista ficarem sincronizados.
    return BlocProvider(
      create: (_) => HomeCubit()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // SEMPRE valida contra server, mesmo se cache local diz "onboarded=true".
    // Antes só checava quando cache != true → se Hive estava stale (ex: user
    // perdeu profile no server mas o flag local sobreviveu), home nunca
    // detectava e o user ficava preso vendo "perfil incompleto" eternamente.
    _checkOnboarding(onboardingCacheStatus());
    // Cidade + clima — idempotente, dispara só 1x por sessão.
    locationWeatherController.initIfNeeded();
    // Audio route — escuta mudanças de fones/AirPods/BT no header da Home.
    // Idempotente; falha silenciosa em web.
    audioRouteService.init();
    // Permissões + sync de saúde. ensureAuthorizations re-prompt iOS pra
    // tipos novos (ex: SLEEP_ASLEEP) caso o user tenha feito onboarding
    // antes desses tipos serem adicionados — sem isso, a lista de
    // Configurações > Saúde > Runnin fica só com "Batimentos".
    _bootstrapHealth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Volta do bg → puxa HK sem gate (user acorda, abre o app, espera ver
    // sono atualizado). Antes tinha staleness de 30min que segurava o
    // sync quando ele tinha aberto o app de noite e voltou de manhã com
    // o sono do Watch chegando no HK só depois do limite.
    if (state == AppLifecycleState.resumed) {
      _refreshHealthAndReload();
    }
  }

  Future<void> _bootstrapHealth() async {
    // Fix TF 60: ping incondicional ANTES de qualquer gate. Server loga
    // `wearable.sync.ping` no Cloud Run — se ping não aparece nos logs, o
    // user não chegou aqui. Se aparece mas telemetry não, syncSince morreu
    // em algum lugar (= log do catch agora cobre).
    unawaited(BiometricRemoteDatasource().syncPing(
      tfHint: '60',
      platform: 'ios',
    ));
    try {
      await healthSyncService.ensureAuthorizations();
      await _refreshHealthAndReload();
    } catch (_) {/* best-effort, telemetria sai do service */}
  }

  /// Roda HK→server sync e, ao terminar, recarrega o HomeCubit pra
  /// puxar a nova summary (sleep da noite, BPM repouso, HRV, 7d stats).
  /// Sem `showLoading` pra não piscar a tela — atualização silenciosa.
  /// Sempre dispara um `forceFullResync` em paralelo (janela 7d) como
  /// safety-net: cobre o caso "lastSync recente perde sleep overnight"
  /// reportado pelo user (sleep ficou em data congelada mesmo com fix 36h).
  Future<void> _refreshHealthAndReload() async {
    try {
      await healthSyncService.syncSince();
      // ignorando erro; safety net abaixo cobre o caso.
      unawaited(healthSyncService.forceFullResync());
    } catch (_) {/* best-effort, eventos de erro já saem do service */}
    if (!mounted) return;
    try {
      context.read<HomeCubit>().load(showLoading: false);
    } catch (_) {/* cubit pode não estar disponível em alguns paths */}
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
    } catch (_) {/* offline OU server down — segue com cache */}
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
                  _HomeHeader(
                    profileName: state is HomeLoaded ? state.data.profile?.name : null,
                    hasWearable: state is HomeLoaded ? (state.data.profile?.hasWearable ?? false) : false,
                  ),
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
                    // Lê via subscriptionController (fonte de verdade pós-paywall).
                    // O `state.data.profile?.premium` vinha do cache do dashboard
                    // e ficava stale após o upgrade → card de paywall continuava
                    // visível até reload manual. ListenableBuilder garante
                    // rebuild quando subscriptionController.refresh() é chamado.
                    ListenableBuilder(
                      listenable: subscriptionController,
                      builder: (_, _) {
                        final isPro = subscriptionController.isPro ||
                            (state.data.profile?.premium ?? false);
                        if (isPro) return const SizedBox.shrink();
                        return Column(
                          children: [
                            _PremiumUpsellBanner(),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
                    // NOTE: _UserInfoCards (peso/altura/idade/freq) and
                    // _SkinSection used to live here as a dashboard-style
                    // layout. They are PERFIL-owned sections and were
                    // duplicates of identically-named private widgets in
                    // account_page.dart. Removed from HOME to fix the
                    // cross-tab content leak reported by the user.
                    // B2 SUP-406 Section 1 — Coach Brief + INICIAR
                    _IniciarSessaoButton(data: state.data),
                    const SizedBox(height: 20),
                    // Notificações migraram pro ícone (sino) no cabeçalho da
                    // Home → tela /notifications. Dropdown antigo removido.
                    // B4-B6: SEMANA / PERFORMANCE / COACH RESUMO são
                    // detalhes do plano + curadoria do coach AI → Premium.
                    // Freemium vê 1 card de paywall agrupado no lugar das
                    // 3 seções pra não poluir o feed com 3 banners iguais.
                    ListenableBuilder(
                      listenable: subscriptionController,
                      builder: (_, _) {
                        final isPro = subscriptionController.isPro ||
                            (state.data.profile?.premium ?? false);
                        if (isPro) {
                          return Column(
                            children: [
                              _SemanaSection(data: state.data),
                              const SizedBox(height: 20),
                              _PerformanceSection(data: state.data),
                              const SizedBox(height: 20),
                              _CoachAiWeeklySummary(data: state.data),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                        return Column(
                          children: const [
                            PremiumLockedCard(
                              title: 'PLANO • PERFORMANCE • COACH AI',
                              description:
                                  'Distribuição semanal, métricas de pace/BPM '
                                  'e resumo do coach AI são Premium. Sua '
                                  'corrida livre e os dados pessoais seguem '
                                  'liberados abaixo.',
                              icon: Icons.lock_outline,
                              next: '/home',
                            ),
                            SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
                     // B7 SUP-411 Section 6 — Status Corporal (REAL)
                     ///status corporal implements all 4 metrics with real data: Prontidão, Sono, Carga Muscular, Hidratação
                     _StatusCorporalSection(
                       key: statusCorporalSectionKey,
                       data: state.data,
                     ),
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
  final bool hasWearable;
  const _HomeHeader({this.profileName, this.hasWearable = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

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
        // Canto superior direito: WATCH + AUDIO + sino. Lit/unlit segue
        // estado real (WATCH: profile.hasWearable; AUDIO: estático off por
        // enquanto, sem API web pra detectar BT). Clique em cada um leva
        // pra config correspondente.
        Row(
          children: [
            _HeaderIconButton(
              icon: Icons.watch_outlined,
              isOn: hasWearable,
              palette: palette,
              tooltip: 'WATCH',
              onTap: () => context.push('/profile/health/devices'),
            ),
            const SizedBox(width: 14),
            // AUDIO: lit quando audioRouteService detecta fone/AirPods/BT.
            // ListenableBuilder rebuilda o ícone quando o user pluga/desconecta.
            ListenableBuilder(
              listenable: audioRouteService,
              builder: (_, _) => _HeaderIconButton(
                icon: Icons.headphones_outlined,
                isOn: audioRouteService.hasExternalAudio,
                palette: palette,
                tooltip: 'AUDIO',
                onTap: () => _openBluetoothSettings(context),
              ),
            ),
            const SizedBox(width: 14),
            const _NotificationBell(),
          ],
        ),
      ],
    );
  }
}

/// Botão de ícone do header (WATCH/AUDIO) — mesmo footprint visual do
/// sino: ícone 24x24, branco quando ligado, atenuado quando desligado.
/// Dot indicator em volta sinaliza o estado.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isOn;
  final RunninPalette palette;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.isOn,
    required this.palette,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOn ? Colors.white : Colors.white.withValues(alpha: 0.40);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: color, size: 24),
            if (isOn)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar instrutivo do ícone AUDIO. Quando há fone detectado, confirma
/// qual é (ex: "Áudio saindo via AirPods Pro"); quando não há, instrui o
/// user a conectar via Bluetooth do sistema. Não abre settings nativo —
/// quando o app migrar pra mobile-only podemos trocar por
/// AppSettings.openAppSettings(type: bluetooth).
Future<void> _openBluetoothSettings(BuildContext context) async {
  final hasExternal = audioRouteService.hasExternalAudio;
  final deviceName = audioRouteService.activeDeviceName;
  final msg = hasExternal
      ? (deviceName != null
          ? 'Áudio saindo via $deviceName.'
          : 'Fone detectado — áudio do coach sai por ele.')
      : 'Áudio do coach sai pelo dispositivo conectado. Conecte/troque '
          'fones de ouvido pelo Bluetooth do seu sistema.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1A2A),
      content: Text(
        msg,
        style: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      duration: const Duration(seconds: 4),
    ),
  );
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
        onCta: () => context.push('/training/criar-plano'),
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
    final sessionDone = session != null && session.isExecuted;

    // Coach AI message block from Figma
    final coachMessage = session == null
        ? 'Nenhuma sessao planejada para hoje. Use uma corrida livre ou revise a distribuicao da semana no modulo de treino.'
        : sessionDone
            ? '✓ Sessão de hoje concluída: ${session.type}. Bom trabalho! Quer uma corrida livre extra?'
            : '${session.type} hoje — pace alvo ${session.targetPace ?? "livre"}. Foco em cadencia e respiracao.';

    // _CyberTodayCard movido pra dentro do _HeroSection (evita duplicação).
    // Aqui fica só Coach AI + CTA INICIAR.
    final isPremium = data.profile?.premium ?? false;
    return _CoachMessageCard(
      palette: palette,
      message: coachMessage,
      ctaLabel: isPremium && session != null && !sessionDone
          ? 'INICIAR SESSAO ↗'
          : 'INICIAR CORRIDA LIVRE ↗',
      onCta: () async {
        // Sessão guiada AI (não concluída) sem premium = paywall. Sessão já
        // concluída ou sem sessão → corrida livre, sem paywall.
        if (!isPremium && session != null && !sessionDone) {
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
                        onTap: () {
                          final now = DateTime.now();
                          final monday =
                              now.subtract(Duration(days: now.weekday - 1));
                          final weekStart =
                              '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
                          context.push('/training/report/$weekStart');
                        },
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
    // Semana do plano em curso (não a semana ISO do ano).
    final weekNum = data.currentPlanWeekNumber ?? _isoWeekNumber(now);
    final monthAbbr = _monthAbbr(monday.month);
    // Volume = km executados / km planejados (somando as sessões da semana
    // pelo plano vigente). Antes a barra usava sessions count e o
    // denominador era plannedSessions × 5km — não batia com o label nem com
    // os km reais. Agora é km-vs-km, coerente com a copy "X / Y km".
    final plannedKm = _plannedWeeklyDistance(data);
    final volumePct = plannedKm <= 0
        ? 0.0
        : (data.weeklyDistanceKm / plannedKm).clamp(0.0, 1.0);

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
                // status reflete só o conteúdo da célula (rest/done/planned).
                // O destaque de HOJE vai por `isToday` separado, pra cobrir
                // também dias de descanso (sem sessão).
                status: d.session == null
                    ? wg.WeekDayCellStatus.rest
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
                // Corrida realizada → ícone vira check (mesmo no card de HOJE).
                executed: d.isDone,
                isToday: d.isToday,
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
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.08,
              ),
            ),
            const Spacer(),
            Text(
              '${data.weeklyDistanceKm.toStringAsFixed(1)} / ${plannedKm.toStringAsFixed(1)} km',
              style: TextStyle(
                color: palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MiniProgressBar(value: volumePct, color: palette.primary, minHeight: 6),
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
  final double minHeight;
  /// Cor do trilho (fundo). Null = palette.border. Útil quando a barra fica
  /// sobre um card colorido (ex.: hidratação no card primário).
  final Color? trackColor;

  const _MiniProgressBar({
    required this.value,
    required this.color,
    this.minHeight = 3,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: LinearProgressIndicator(
        minHeight: minHeight,
        value: value.clamp(0.0, 1.0),
        backgroundColor: trackColor ?? palette.border,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PACE TREND',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        avgPace ?? '--',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.02,
                        ),
                      ),
                      Text(
                        avgPace != null
                            ? '/km · media das corridas'
                            : 'sem corridas suficientes',
                        style: TextStyle(color: palette.muted, fontSize: 10),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARDIACO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // StreamBuilder com BPM ao vivo do Apple Health /
                      // Health Connect (polling 2min). Fallback pro
                      // run.avgBpm quando o stream emite null (sem wearable,
                      // sem permissão, web).
                      StreamBuilder<int?>(
                        stream: bpmPollingService.latestBpmStream,
                        initialData: bpmPollingService.latestBpm,
                        builder: (context, snap) {
                          final liveBpm = snap.data;
                          final bpm = liveBpm ?? run?.avgBpm;
                          final isLive = liveBpm != null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bpm != null ? '$bpm' : '--',
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                bpm == null
                                    ? 'sem BPM registrado'
                                    : isLive
                                        ? 'bpm recente (wearable)'
                                        : 'bpm medio na ultima corrida',
                                style: TextStyle(color: palette.muted, fontSize: 10),
                              ),
                              const SizedBox(height: 20),
                              if (bpm != null) ...[
                                Text(
                                  'ZONA ESTIMADA',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '$bpm',
                                  style: TextStyle(
                                    color: palette.secondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _ZoneBars(avgBpm: bpm),
                              ] else
                                TextButton(
                                  onPressed: () => context.push('/profile/edit'),
                                  child: const Text('REVISAR DADOS'),
                                ),
                            ],
                          );
                        },
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
                  color: palette.secondary,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOLUME SEMANAL',
                        style: TextStyle(
                          color: palette.background.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          weeklyCompletion == null
                              ? 'SEM PLANO'
                              : '${(weeklyCompletion * 100).round()}%',
                          style: TextStyle(
                            color: palette.background,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        weeklyCompletion == null
                            ? 'Crie um plano pra acompanhar seu volume'
                            : 'do volume planejado que você já correu nesta semana',
                        style: TextStyle(
                          color: palette.background.withValues(alpha: 0.78),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      if (weeklyCompletion == null)
                        TextButton(
                          onPressed: () => context.push('/training'),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.background,
                            padding: const EdgeInsets.only(top: 4),
                          ),
                          child: const Text('VER PLANO'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STREAK',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
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
                        style: TextStyle(color: palette.muted, fontSize: 12),
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
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.06,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('KM', style: TextStyle(color: palette.muted, fontSize: 10)),
            Text(
              data.weeklyDistanceKm.toStringAsFixed(1),
              style: TextStyle(
                color: palette.text,
                fontSize: 12,
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
  const _StatusCorporalSection({super.key, required this.data});

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
    final muscleEst = _muscleLoadEstimate(widget.data);
    final muscleLoad = muscleEst.label;
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
                child: Builder(builder: (_) {
                  // Diferencia 3 estados: (a) tem sono, (b) wearable conectado
                  // mas sono ausente E outros sinais presentes = provável
                  // permissão de "Sono" não concedida no iOS, (c) sem origem
                  // alguma de saúde. O caso (b) leva direto pra /profile/health
                  // pra revisar permissão, em vez de /profile/edit.
                  final sleepGap = _hasSleepPermissionGap(widget.data);
                  // Última noite em destaque + média 7d no slot do chart.
                  final bio = widget.data.biometric;
                  final lastNight = bio?.lastNightSleepHours;
                  final avg7d = bio?.avgSleepHours;
                  return MetricCard(
                    label: 'SONO',
                    value: lastNight != null
                        ? _hoursToHhMm(lastNight)
                        : '--',
                    unit: null,
                    valueColor: FigmaColors.textPrimary,
                    sub: lastNight != null
                        ? 'Última noite via Apple Health'
                        : sleepGap
                            ? "Permita 'Sono' em Saúde do iPhone"
                            : profile?.hasWearable == true
                                ? 'Sem sono sincronizado via Health'
                                : 'Sem origem de sono conectada',
                    chart: lastNight != null
                        ? Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Média 7d',
                                style: TextStyle(
                                  color: context.runninPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                avg7d != null ? _hoursToHhMm(avg7d) : '—',
                                style: TextStyle(
                                  color: context.runninPalette.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : TextButton(
                            onPressed: () => context.push(
                              sleepGap ? '/profile/health' : '/profile/edit',
                            ),
                            child: Text(
                              sleepGap
                                  ? 'REVISAR PERMISSÕES'
                                  : 'REVISAR PERFIL',
                            ),
                          ),
                  );
                }),
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
                  sub: muscleEst.hint ??
                      (hasBpmData
                          ? 'Com BPM e volume da semana'
                          : 'Sem BPM real; por distancia/volume'),
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
                  // Card com fundo da cor primária da skin → texto/elementos
                  // na cor base (escura) pra contraste. MetricCard já deixa
                  // label/sub na base; valueColor explícito p/ não herdar o
                  // primary (invisível sobre fundo primary).
                  backgroundColor: context.runninPalette.primary,
                  value: hydrationLoggedL == null
                      ? '--'
                      : '${hydrationLoggedL.toStringAsFixed(1)}L',
                  unit: hydrationGoalL == null
                      ? null
                      : '/${hydrationGoalL.toStringAsFixed(1)}L',
                  valueColor: context.runninPalette.background,
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
                          color: context.runninPalette.background,
                          trackColor: context.runninPalette.background
                              .withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton(
                        onPressed: hydrationGoalL == null
                            ? () => context.push('/profile/edit')
                            : () => _openHydrationSheet(goalLiters: hydrationGoalL),
                        style: TextButton.styleFrom(
                          foregroundColor: context.runninPalette.background,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
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
/// Converte horas decimais pra formato "h:mm" (ex: 5.3h → "5:18").
/// Usado pra exibir tempo de sono e duração de corrida em padrão temporal
/// claro (compatível com o que Apple Health mostra).
String _hoursToHhMm(num hours) {
  final totalMin = (hours * 60).round();
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

String? _averagePace(List<Run> runs) {
  // Filtro ruído: corridas curtas (<30s) ou sem deslocamento (<100m) são
  // descartadas — espelha o filtro server (get-stats-aggregate.use-case.ts)
  // pra os cards do app não divergirem da API. User tocou INICIAR e fechou,
  // ou GPS perdeu sinal e a "corrida" ficou parada.
  final validRuns = runs
      .where((run) => run.distanceM >= 100 && run.durationS >= 30)
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

/// True quando o user sincronizou OUTROS dados de saúde (BPM resting ou
/// max) mas sono está ausente — sinal forte de que concedeu HK no geral mas
/// negou (ou nunca registrou) o tipo "Sono". Driver do banner SONO da home
/// pedir pra revisar permissão.
bool _hasSleepPermissionGap(HomeData data) {
  final bio = data.biometric;
  if (bio == null) return false;
  if (bio.avgSleepHours != null && bio.avgSleepHours! > 0) return false;
  return bio.avgRestingBpm != null || bio.maxBpm != null;
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

/// Carga muscular combina volume (distância) + intensidade (maxBpm vs limite
/// pessoal) + sinal de stress (resting elevado). Antes era só volume — uma
/// corrida intensa de 5km com BPM beirando o máximo ficava como "BAIXA",
/// que escondia o esforço real e atrapalhava a recuperação sugerida.
///
/// Heurística em 3 níveis com bumps:
///   base = BAIXA, +1 se volume médio (latest>=6km OU semana>=15km),
///          +1 se volume alto (latest>=12km OU semana>=30km).
///   bump = +1 se maxBpm da última run >= 90% do max pessoal (intensidade alta).
///   bump = +1 se avgRestingBpm do summary >= profile.restingBpm + 8 (stress).
///   Cap em ALTA. Sub-label diz qual sinal puxou (ex: "pelo BPM").
({String label, String? hint}) _muscleLoadEstimate(HomeData data) {
  final latest = data.latestRun;
  final latestDistance = (latest?.distanceM ?? 0) / 1000;
  final weekly = data.weeklyDistanceKm;
  final profile = data.profile;
  final summary = data.biometric;

  var level = 0;
  if (latestDistance >= 6 || weekly >= 15) level += 1;
  if (latestDistance >= 12 || weekly >= 30) level += 1;

  // Limite pessoal de BPM: prefere o declarado; senão estima 220-idade
  // a partir do birthDate (mesmo cascade que health_zones_page usa).
  int? personalMax = profile?.maxBpm;
  if (personalMax == null) {
    final age = _ageFromBirthDateInt(profile?.birthDate);
    if (age != null && age > 0 && age < 120) personalMax = 220 - age;
  }
  String? hint;
  if (latest?.maxBpm != null && personalMax != null) {
    final ratio = latest!.maxBpm! / personalMax;
    if (ratio >= 0.90) {
      level += 1;
      hint = 'pico de BPM próximo do limite';
    }
  }

  // Stress por resting elevado: avgRestingBpm dos últimos 7d acima do
  // declarado em 8bpm já sugere recuperação incompleta (overreaching).
  final personalResting = profile?.restingBpm;
  final recentResting = summary?.avgRestingBpm;
  if (personalResting != null && recentResting != null && recentResting >= personalResting + 8) {
    level += 1;
    hint ??= 'BPM repouso elevado';
  }

  final label = level >= 3 ? 'ALTA' : level >= 1 ? 'MEDIA' : 'BAIXA';
  return (label: label, hint: hint);
}

/// Idade em anos a partir de um ISO date string. null pra entrada vazia
/// ou inválida. Usado no fallback de maxBpm (220 - idade) quando o
/// usuário não declarou o limite.
int? _ageFromBirthDateInt(String? birthDate) {
  if (birthDate == null || birthDate.isEmpty) return null;
  final dt = DateTime.tryParse(birthDate);
  if (dt == null) return null;
  final now = DateTime.now();
  var age = now.year - dt.year;
  if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
    age -= 1;
  }
  return age > 0 ? age : null;
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
    
    final session = data.todaySession;
    const heroAsset = 'assets/img/hero/runner_home.jpg';

    final weekdayLabel = _weekdayLabel(now.weekday).toUpperCase();
    // Semana do PLANO em curso (não a semana ISO do ano). Fallback p/ ISO só
    // quando não há plano ativo.
    final weekNumber = data.currentPlanWeekNumber ?? _isoWeekNumber(now);
    // Sessão de hoje já executada → pill vira "<tipo> · CONCLUÍDA" na cor
    // secundária (em vez da primária).
    final sessionDone = session != null && session.isExecuted;
    final sessionType = (session?.type ?? 'LIVRE').toUpperCase();
    final distanceLabel = session != null
        ? '${session.distanceKm.toStringAsFixed(session.distanceKm % 1 == 0 ? 0 : 1)}K'
        : '—';
    final paceLabel = session?.targetPace ?? '—:—';
    final etaLabel = session != null
        ? '~${(session.distanceKm * _paceSecPerKm(session.targetPace) / 60).round()}min'
        : '';

    return Container(
      height: 540,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        image: DecorationImage(
          image: const AssetImage(heroAsset),
          // Foto é ULTRA portrait (704x1524, aspect 0.46). fitHeight
          // deixava a imagem fina (~250px) com tarja escura larga à
          // esquerda — visualmente quebrado. cover preenche o container
          // sempre; topCenter privilegia mountains + rosto do corredor
          // e corta as pernas (parte menos interessante). Overlay de
          // gradient (logo abaixo) mantém o texto legível.
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
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
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // City + clima lêem o controller — escondem silenciosamente
                // quando permissão negada ou Open-Meteo falhou.
                ListenableBuilder(
                  listenable: locationWeatherController,
                  builder: (context, _) {
                    final city = locationWeatherController.city;
                    final weather = locationWeatherController.weather;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (city != null && city.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 18),
                              Icon(Icons.place_outlined,
                                  size: 12, color: Colors.white.withValues(alpha: 0.72)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  city.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.78),
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // WATCH + AUDIO chips moveram pro header (ao lado do
                        // sino), ficaram só weather + city visíveis aqui.
                        if (weather != null) ...[
                          const SizedBox(height: 14),
                          _WeatherStrip(weather: weather),
                        ],
                      ],
                    );
                  },
                ),
                const Spacer(),
                // HOJE — bem grande, logo acima do session pill
                Text(
                  'HOJE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 53,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -1.4,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                // EASY RUN pill + dia · semana
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: sessionDone ? palette.secondary : palette.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sessionType,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                          // "CONCLUÍDA" embaixo (não na mesma linha) pra não
                          // empurrar o rótulo de data ao lado.
                          if (sessionDone)
                            Text(
                              'CONCLUÍDA',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '$weekdayLabel · SEM $weekNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 1.0,
                        ),
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
                                    color: palette.secondary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: '/km',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.secondary.withValues(alpha: 0.85),
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

/// Strip discreta de clima abaixo dos chips WATCH/AUDIO. Mesmo background
/// dos chips mas sem dot indicator (não é status de conexão, é dado
/// ambiental). Esconde-se quando weather=null (sem permissão / API down).
class _WeatherStrip extends StatelessWidget {
  final WeatherSnapshot weather;
  const _WeatherStrip({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeatherCell(
            icon: Icons.thermostat,
            value: '${weather.temperatureC.toStringAsFixed(0)}°',
          ),
          _WeatherDivider(),
          _WeatherCell(
            icon: Icons.water_drop_outlined,
            value: '${weather.humidityPercent}%',
          ),
          _WeatherDivider(),
          _WeatherCell(
            icon: Icons.air,
            value: '${weather.windKmh.toStringAsFixed(0)}km/h',
          ),
          if (weather.uvIndex != null) ...[
            _WeatherDivider(),
            _WeatherCell(
              icon: Icons.wb_sunny_outlined,
              value: 'UV ${weather.uvIndex!.toStringAsFixed(0)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherCell extends StatelessWidget {
  final IconData icon;
  final String value;
  const _WeatherCell({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.78)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.88),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _WeatherDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.20),
      );
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
                    'Plano personalizado, coach ao vivo e integração com Apple Health / Google Health Connect. R\$ 19,90/mês.',
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



// ─── Sino de notificações (cabeçalho da Home) ────────────────────────────────
class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final unread = state is NotificationsLoaded
            ? state.items.where((n) => n.readAt == null && n.dismissedAt == null).length
            : 0;
        return GestureDetector(
          onTap: () => context.push('/notifications'),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
