import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/debug/mock_gps_service.dart';
import 'package:runnin/core/notifications/run_bg_notification_service.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/badges/presentation/pages/badge_popup_modal.dart';
import 'package:runnin/features/run/domain/entities/run.dart' show GpsPoint;
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/widgets/gps_permission_modal.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';

/// Página da corrida ativa. Aceita `initialType` que vem da última tela
/// do wizard /prep. Inicia em modo IDLE com botão INICIAR + status chips
/// (gps/coach/música/wearable). Só depois do user pressionar INICIAR,
/// dispatch StartRun → bloc cria runId + abre GPS stream + dispara
/// saudação. Final-state: ABANDONAR | FINALIZAR.
class ActiveRunPage extends StatelessWidget {
  /// Tipo da corrida selecionado no /prep (Free Run, Long Run, etc.)
  /// Usado pra dispatch StartRun quando user pressionar INICIAR.
  final String initialType;
  /// ID da sessão do plano que essa run vai executar. Vem via query
  /// (?planSessionId=...) ou deep link de TREINO. Server marca a sessão
  /// como "feita" ao completar.
  final String? planSessionId;
  /// Toggles de alerta per-session escolhidos no /prep (passo 3/4). Herdam do
  /// default global e valem só pra esta corrida.
  final Map<String, bool>? alertPrefs;
  /// Plano resolvido no /prep — null = fallback pro [subscriptionController]
  /// no momento do INICIAR (refletido em [_resolveIsPremium]). Determina
  /// se a run abre coach AI ao vivo (premium) ou usa TTS de telemetria
  /// on-device a cada km (freemium).
  final bool? isPremium;
  /// Quando true, dispara StartRun automaticamente no primeiro frame após
  /// mount — sem aguardar tap manual no botão INICIAR. Usado pelo
  /// WatchStartListener quando o Watch dispara `startRun` e o iPhone
  /// estava fora do shell de corrida.
  final bool autoStart;
  /// True = corrida em esteira: GPS desligado, distância informada no finish.
  final bool indoor;
  /// Alvo da corrida de AVALIAÇÃO (km). Seta a meta de distância do bloc
  /// (goal_reached) e marca a run no server como assessment.
  final double? assessmentTargetKm;
  const ActiveRunPage({
    super.key,
    this.initialType = 'Free Run',
    this.planSessionId,
    this.alertPrefs,
    this.isPremium,
    this.autoStart = false,
    this.indoor = false,
    this.assessmentTargetKm,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<RunBloc, RunState>(
      listenWhen: (_, curr) => curr.status == RunStatus.completed,
      listener: (context, state) {
        final runId = state.completedRun?.id ?? state.runId ?? '';
        // TF 79: unlockedBadges vem populado pelo PATCH /runs/:id/complete.
        // Mostra BadgePopupModal full-screen estilo Stories pra cada badge
        // antes de navegar pro /report. isAutoUnlock=true → markSeen no close.
        final badges = state.completedRun?.unlockedBadges ?? const [];
        if (badges.isNotEmpty) {
          _showBadgePopups(context, badges, runId);
        } else {
          context.pushReplacement('/report', extra: runId);
        }
      },
      child: _ActiveRunView(
        initialType: initialType,
        planSessionId: planSessionId,
        alertPrefs: alertPrefs,
        isPremium: isPremium,
        autoStart: autoStart,
        indoor: indoor,
        assessmentTargetKm: assessmentTargetKm,
      ),
    );
  }

  /// Mostra `BadgePopupModal` em sequência pra cada badge desbloqueado. Após
  /// o último ser dispensado, navega pra `/report`. Substitui o
  /// `FigmaBadgeUnlockModal` legado (que usava `Run.newBadges: List<String>`
  /// nunca mais populado) — agora usa o sistema de badges full do server
  /// com card visual + share, igual ao popup automático do boot da home.
  static Future<void> _showBadgePopups(
    BuildContext context,
    List badges,
    String originalRunId,
  ) async {
    for (final badge in badges) {
      if (!context.mounted) return;
      await BadgePopupModal.show(context, badge, isAutoUnlock: true);
    }
    if (!context.mounted) return;
    context.pushReplacement('/report', extra: originalRunId);
  }
}

class _ActiveRunView extends StatefulWidget {
  final String initialType;
  final String? planSessionId;
  final Map<String, bool>? alertPrefs;
  final bool? isPremium;
  /// Dispara StartRun no primeiro frame quando true. Usado pelo Watch que
  /// inicia corrida com iPhone fora do shell (ver WatchStartListener).
  final bool autoStart;
  final bool indoor;
  final double? assessmentTargetKm;
  const _ActiveRunView({
    required this.initialType,
    this.planSessionId,
    this.alertPrefs,
    this.isPremium,
    this.autoStart = false,
    this.indoor = false,
    this.assessmentTargetKm,
  });

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  bool _coachMuted = false;
  bool _coachAudioPlaying = false;
  // Resolução de plano: prefere o que veio do prep. Fallback pro
  // subscriptionController em runtime se o prep não passou (deep link).
  bool get _isPremium => widget.isPremium ?? subscriptionController.isPro;
  // Coach banner auto-fade. Mostra mensagem por 10s e depois esconde
  // (mas o áudio continua tocando se ainda não terminou).
  String? _lastBannerMessageShown;
  bool _bannerVisible = false;
  Timer? _bannerHideTimer;

  @override
  void dispose() {
    _bannerHideTimer?.cancel();
    super.dispose();
  }
  _GpsStatus _gpsStatus = _GpsStatus.unknown;

  @override
  void initState() {
    super.initState();
    // Modal SÓ abre quando GPS precisa de ação do user (permissão negada
    // ou serviço desligado). Pra status 'unknown' (ainda resolvendo) e
    // 'ok', não mostra nada — o navegador/SO pede permissão nativa
    // automaticamente quando getCurrentPosition é chamado.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshGpsStatus();
      if (!mounted) return;
      final needsAction = _gpsStatus == _GpsStatus.denied ||
          _gpsStatus == _GpsStatus.off;
      // Quando autoStart (corrida iniciada pelo Watch), NÃO bloqueia com modal —
      // user provavelmente está olhando pro Watch, não pro iPhone. RunBloc.
      // _onStart trata permissão negada propagando erro pro state. Quando é
      // tap manual no iPhone (autoStart=false) e GPS está bloqueado, modal
      // ainda aparece pro user reagir.
      // Indoor (esteira): GPS não é usado — não bloqueia com modal.
      if (needsAction && !widget.autoStart && !widget.indoor) {
        final granted = await GpsPermissionModal.show(
          context,
          blocked: true,
        );
        if (granted && mounted) await _refreshGpsStatus();
      }
      // autoStart vem do Watch (via WatchStartListener) — não esperamos o
      // user bater INICIAR. Dispatch direto após GPS resolver. Se permissão
      // foi negada, RunBloc trata graciosamente (timer roda sem GPS).
      if (widget.autoStart && mounted) {
        unlockAudioContext();
        final isPremium =
            widget.isPremium ?? subscriptionController.isPro;
        context.read<RunBloc>().add(StartRun(
              type: widget.initialType,
              planSessionId: widget.planSessionId,
              alertPrefs: widget.alertPrefs,
              isPremium: isPremium,
              indoor: widget.indoor,
              assessmentTargetKm: widget.assessmentTargetKm,
            ));
      }
    });
  }

  Future<void> _openPermissionModal() async {
    final granted = await GpsPermissionModal.show(
      context,
      blocked: _gpsStatus == _GpsStatus.denied || _gpsStatus == _GpsStatus.off,
    );
    if (granted && mounted) await _refreshGpsStatus();
  }

  Future<void> _refreshGpsStatus() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
        return;
      }
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.denied);
        return;
      }
      if (mounted) setState(() => _gpsStatus = _GpsStatus.ok);
    } catch (_) {
      if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
    }
  }

  /// Dialog de "parado": a corrida foi pausada após 30s sem deslocamento.
  /// CONTINUAR retoma; ENCERRAR abandona e volta pra home.
  Future<void> _showNoMovementDialog(BuildContext context) async {
    final bloc = context.read<RunBloc>();
    final router = GoRouter.of(context);
    final palette = context.runninPalette;
    final keepGoing = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: const Text('VOCÊ PAROU?'),
        content: const Text(
          'Não detectamos movimento nos primeiros 30 segundos, então pausamos '
          'sua corrida. Quer continuar ou encerrar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ENCERRAR', style: TextStyle(color: palette.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONTINUAR'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    bloc.add(DismissNoMovementPrompt());
    if (keepGoing == true) {
      bloc.add(ResumeRun());
    } else {
      bloc.add(AbandonRun());
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: MultiBlocListener(
        listeners: [
          // Parado em 30s: a bloc pausou e marcou noMovementPrompt → dialog.
          BlocListener<RunBloc, RunState>(
            listenWhen: (prev, curr) =>
                !prev.noMovementPrompt && curr.noMovementPrompt,
            listener: (context, state) => _showNoMovementDialog(context),
          ),
          BlocListener<RunBloc, RunState>(
        // Tocar SÓ quando o audio MUDA. Antes só checava "tem audio?",
        // então cada tick do timer/GPS update reemitia o player → áudio
        // repetia em loop curto. Comparar prev != curr garante 1 play por cue.
        listenWhen: (prev, curr) =>
            (curr.coachAudioBase64 != null &&
                curr.coachAudioBase64!.isNotEmpty &&
                curr.coachAudioBase64 != prev.coachAudioBase64) ||
            (curr.coachLiveMessage != null &&
                curr.coachLiveMessage!.isNotEmpty &&
                curr.coachLiveMessage != _lastBannerMessageShown),
        listener: (context, state) {
          // Banner: mostra mensagem nova + auto-hide após 10s.
          // Áudio segue tocando mesmo após banner sumir.
          if (state.coachLiveMessage != null &&
              state.coachLiveMessage!.isNotEmpty &&
              state.coachLiveMessage != _lastBannerMessageShown) {
            _lastBannerMessageShown = state.coachLiveMessage;
            setState(() => _bannerVisible = true);
            _bannerHideTimer?.cancel();
            _bannerHideTimer = Timer(const Duration(seconds: 10), () {
              if (mounted) setState(() => _bannerVisible = false);
            });
          }
          if (_coachMuted) return;
          if (state.coachAudioBase64 == null || state.coachAudioBase64!.isEmpty) {
            return;
          }
          playCoachAudio(
            state.coachAudioBase64!,
            mimeType: state.coachAudioMimeType ?? 'audio/mpeg',
            volume: 1.0,
          ).then((_) => setState(() => _coachAudioPlaying = true));
        },
          ),
        ],
        child: BlocBuilder<RunBloc, RunState>(
          builder: (context, state) {
            // View ÚNICA — idle e active compartilham layout (mapa
            // placeholder + stats + chips). O que muda é o conjunto de
            // botões no rodapé: INICIAR em idle/starting, ABANDONAR +
            // FINALIZAR quando rodando. Timer só sobe quando active
            // (RunBloc._onTimerTick gate-ado por status).
            final isIdle = state.status == RunStatus.idle ||
                state.status == RunStatus.starting;
            // GPS status real: em idle vem da checagem de permissão;
            // em active baseia em points recebidos (≥1 = OK; 0 = aguardando).
            final gpsChipStatus = isIdle
                ? _gpsStatus
                : (state.points.isNotEmpty
                    ? _GpsStatus.ok
                    : _GpsStatus.unknown);
            return Stack(
              children: [
                // Mapa em DESTAQUE no FUNDO (tela cheia). A telemetria fica na
                // metade de baixo e o cronômetro no meio-esquerda (overlays).
                // Indoor: sem GPS não há rota — fundo dark sólido no lugar
                // do mapa (mapa vazio em (0,0) parecia bug).
                if (isIdle)
                  const _IdleHeroBackground()
                else if (widget.indoor)
                  const _IndoorBackground()
                else
                  _RouteMap(points: state.points),
                // Banner discreto quando Live Activities está desabilitada
                // em Ajustes. Detectado pelo plugin retornando reason=
                // activities_disabled — surfa pro user com instrução curta
                // pra reativar (sem isso a notif fica pequena silenciosamente).
                if (!isIdle && runBgNotificationService.isLiveActivityDisabled)
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          border: Border.all(
                            color: context.runninPalette.muted.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Notificação ao vivo desligada · Ajustes → Notificações → Runnin → Atividades Ao Vivo',
                          textAlign: TextAlign.center,
                          style: context.runninType.labelCaps.copyWith(
                            color: context.runninPalette.muted,
                            fontSize: 9,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Coach banner: aparece quando cue novo + some após 10s.
                // Posicionado bem mais abaixo pra não sobrepor os chips.
                if (_bannerVisible &&
                    state.coachLiveMessage != null &&
                    state.coachLiveMessage!.isNotEmpty)
                  Positioned(
                    top: 130,
                    left: 16,
                    right: 16,
                    child: _CoachLiveBanner(message: state.coachLiveMessage!),
                  ),
                // Push-to-talk REMOVIDO (migração s6-ai): sessão Live é
                // unidirecional (telemetria → fala). Cues automáticos seguem.
                // Topo: voltar (idle) + linha de chips em Wrap.
                // GPS, COACH, MÚSICA, BPM. Tudo passível de toque (futuro).
                Positioned(
                  top: 12,
                  left: 14,
                  right: 80,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isIdle)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/home');
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  border: Border.all(color: palette.border),
                                ),
                                child: Icon(
                                  Icons.arrow_back,
                                  size: 18,
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // Indoor: GPS não é usado — chip vira ESTEIRA.
                            if (widget.indoor)
                              _StatusChip(
                                icon: Icons.directions_run,
                                label: 'ESTEIRA · INDOOR',
                                color: palette.primary,
                              )
                            else
                            _StatusChip(
                              icon: Icons.gps_fixed,
                              label: switch (gpsChipStatus) {
                                _GpsStatus.unknown => isIdle
                                    ? 'GPS · CONECTANDO'
                                    : 'GPS · AGUARDANDO',
                                _GpsStatus.ok => !isIdle && state.points.isNotEmpty
                                    ? 'GPS · ${state.points.length} pts'
                                    : 'GPS · OK',
                                _GpsStatus.denied => 'GPS · NEGADO',
                                _GpsStatus.off => 'GPS · OFF',
                              },
                              color: gpsChipStatus == _GpsStatus.ok
                                  ? palette.primary
                                  : gpsChipStatus == _GpsStatus.unknown
                                      ? palette.muted
                                      : palette.secondary,
                              onTap: gpsChipStatus == _GpsStatus.ok
                                  ? null
                                  : _refreshGpsStatus,
                              pulsing: gpsChipStatus == _GpsStatus.unknown,
                            ),
                            _StatusChip(
                              icon: _coachAudioPlaying
                                  ? Icons.graphic_eq
                                  : _coachMuted
                                      ? Icons.volume_off_outlined
                                      : Icons.headphones_outlined,
                              // Freemium: chip vira "TELEMETRIA" (TTS on-device
                              // a cada km, sem coach AI). Premium mantém "COACH".
                              label: () {
                                final name = _isPremium ? 'COACH' : 'TELEMETRIA';
                                if (_coachAudioPlaying) return '$name · FALANDO';
                                if (_coachMuted) return '$name · MUTE';
                                return _isPremium
                                    ? '$name · PRONTO'
                                    : '$name · A CADA KM';
                              }(),
                              color: _coachAudioPlaying
                                  ? palette.primary
                                  : _coachMuted
                                      ? palette.muted
                                      : palette.secondary,
                              pulsing: _coachAudioPlaying,
                            ),
                            _BpmStatusChip(
                              state: state,
                              palette: palette,
                            ),
                            if (state.currentSpo2 != null)
                              _Spo2StatusChip(
                                pct: state.currentSpo2!,
                                palette: palette,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Mute + Talk no canto superior direito (apenas em active).
                // Apenas botão MUTE no topo direito durante a corrida.
                // CoachTalkButton (balão) removido — falar com coach via voz
                // contínua não fazia parte do fluxo padrão e poluía a UI.
                if (!isIdle)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: SafeArea(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _CoachMuteButton(
                            muted: _coachMuted,
                            onTap: () => setState(
                                () => _coachMuted = !_coachMuted),
                          ),
                          if (_coachAudioPlaying)
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                // Cronômetro alinhado à ESQUERDA, na MESMA altura do botão de
                // microfone (push-to-talk) à direita — acima do título/painel
                // de telemetria, sem sobrepor "FREE RUN"/"PACE"/"DIST".
                if (!isIdle)
                  Positioned(
                    left: 24,
                    right: 24,
                    // +80pt vs versão anterior (440/300) — user pediu pra subir
                    // o cronômetro + label TEMPO ~2cm pra não ficar colado nos
                    // chips abaixo. 80pt ≈ 2cm em densidades padrão iOS.
                    bottom: state.distanceM > 0 ? 520 : 380,
                    child: Align(
                      // Alinhado à esquerda.
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.formattedElapsed,
                            style: context.runninType.dataXl.copyWith(
                              fontSize: 58,
                              color: palette.text,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'TEMPO',
                            style: context.runninType.labelCaps.copyWith(
                              color: palette.muted,
                              fontSize: 11,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // TELEMETRIA na metade de baixo: sempre visível, sem rolagem.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _StatsOverlay(
                    state: state,
                    initialType: widget.initialType,
                    gpsOk: gpsChipStatus == _GpsStatus.ok,
                    onRetryGps: _openPermissionModal,
                    onStart: () {
                      // Destrava autoplay dentro do user gesture — sem isso a
                      // saudação Live falha silenciosamente em Chrome/Safari/FF.
                      unlockAudioContext();
                      // Plano final: prefere o que veio do prep; fallback pro
                      // subscriptionController quando prep não setou (deep
                      // link direto pra /run sem passar pelo wizard).
                      final isPremium =
                          widget.isPremium ?? subscriptionController.isPro;
                      context.read<RunBloc>().add(StartRun(
                            type: widget.initialType,
                            planSessionId: widget.planSessionId,
                            alertPrefs: widget.alertPrefs,
                            isPremium: isPremium,
                            indoor: widget.indoor,
                            assessmentTargetKm: widget.assessmentTargetKm,
                          ));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _GpsStatus { unknown, ok, denied, off }

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  /// Dot pulsa quando true — sinal visual de "trabalhando" (conectando,
  /// coach falando). Sem isso o chip parece estático.
  final bool pulsing;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (pulsing) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeOut(duration: const Duration(milliseconds: 700));
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.92),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 6),
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.runninType.labelCaps.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip BPM com 3 estados visuais derivados de [RunState.bpmStaleness]:
///   - fresh: realtime → coração pulsando + cor secundária; fallback → relógio.
///   - stale: cor de aviso (warning), label "BPM · X ?" pra sinalizar dado
///     possivelmente velho mas sem cair pra "—" e perder a leitura útil.
///   - lost:  coração contornado + label "BPM · —" ou "BPM · sem fonte".
///
/// Antes era um único `_StatusChip` inline com 2 ramos lógicos; com 3
/// estados ficou complexo o bastante pra merecer widget próprio. UX:
/// usuário não vê o chip "piscando" pra "—" em cada jitter do Watch.
/// TF 75 Fase 12: chip "SpO2 · 97%" exibido ao lado do BPM. Só renderiza
/// quando há sample recente (Watch Series 6+ pareado).
class _Spo2StatusChip extends StatelessWidget {
  final int pct;
  final RunninPalette palette;
  const _Spo2StatusChip({required this.pct, required this.palette});

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      icon: Icons.water_drop_outlined,
      label: 'SpO₂ · $pct%',
      color: palette.secondary,
      pulsing: false,
    );
  }
}

class _BpmStatusChip extends StatelessWidget {
  final RunState state;
  final RunninPalette palette;
  const _BpmStatusChip({required this.state, required this.palette});

  @override
  Widget build(BuildContext context) {
    final value = state.currentBpm;
    final staleness = state.bpmStaleness;
    final source = state.bpmSource;
    final hasValue = value != null && value > 0;

    IconData icon;
    String label;
    Color color;
    bool pulsing;
    String? suffix;

    // Quando o Apple Watch companion está ativo (paired + appInstalled +
    // reachable durante a corrida), trocamos o ícone pra um relógio sutil
    // — dica visual de que o BPM tá vindo em high-freq via HKWorkoutSession
    // no Watch. Antes era ambíguo entre realtime "qualquer" e fallback poll.
    final watchActive = state.watchStatus?.isOptimal == true &&
        state.status == RunStatus.active;
    switch (staleness) {
      case BpmStaleness.fresh:
        if (watchActive && source == 'realtime') {
          icon = Icons.watch;
        } else if (source == 'fallback') {
          icon = Icons.history;
        } else {
          icon = Icons.favorite;
        }
        color = palette.secondary;
        pulsing = hasValue && source == 'realtime';
        label = hasValue ? 'BPM · $value' : 'BPM · —';
        break;
      case BpmStaleness.stale:
        // Mantém o último valor (informação útil) com sufixo "?" + cor
        // de aviso (recorre ao secondary com opacidade menor — sem token
        // de warning dedicado no palette atual).
        icon = Icons.help_outline;
        color = palette.secondary.withValues(alpha: 0.65);
        pulsing = false;
        label = hasValue ? 'BPM · $value' : 'BPM · —';
        suffix = ' ?';
        break;
      case BpmStaleness.lost:
        icon = Icons.favorite_outline;
        color = palette.muted;
        pulsing = false;
        label = source == 'none' && state.status == RunStatus.active
            ? 'BPM · sem fonte'
            : 'BPM · —';
        break;
    }

    return _StatusChip(
      icon: icon,
      label: suffix != null ? '$label$suffix' : label,
      color: color,
      pulsing: pulsing,
    );
  }
}

class _CoachMuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const _CoachMuteButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return IconButton(
      tooltip: muted ? 'Ativar voz do coach' : 'Mutar voz do coach',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: palette.surface.withValues(alpha: 0.82),
        foregroundColor: muted ? palette.muted : palette.primary,
        side: BorderSide(color: palette.border),
      ),
      icon: Icon(muted ? Icons.volume_off_outlined : Icons.volume_up_outlined),
    );
  }
}
class _RouteMap extends StatelessWidget {
  final List<GpsPoint> points;
  const _RouteMap({required this.points});

  @override
  Widget build(BuildContext context) => _RouteMapBody(points: points);
}

/// Background do estado IDLE — foto da corredora na orla do Rio. Usado em
/// vez do mapa quando user ainda não iniciou. Durante corrida ativa, o mapa
/// real substitui esse hero.
class _IdleHeroBackground extends StatelessWidget {
  const _IdleHeroBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A1A),
          image: DecorationImage(
            image: AssetImage('assets/img/hero/runner_start.jpg'),
            fit: BoxFit.cover,
            // Recorte deslocado pra direita → a corredora assenta no
            // MEIO-DIREITA da tela (a foto é landscape; numa tela retrato
            // o cover corta as laterais).
            alignment: Alignment(0.2, 0.0),
          ),
        ),
      ),
    );
  }
}

class _RouteMapBody extends StatefulWidget {
  final List<GpsPoint> points;
  const _RouteMapBody({required this.points});

  @override
  State<_RouteMapBody> createState() => _RouteMapBodyState();
}

class _RouteMapBodyState extends State<_RouteMapBody> {
  final _mapController = MapController();

  /// Deslocamento de latitude pra centralizar o mapa "abaixo" do marker
  /// — efetivamente puxa o marker pra parte superior da viewport, entre
  /// o chip row (top) e o footer overlay com "RUN.ACTIVE". 0.002° ≈ 220m
  /// em zoom 16, que coloca o marker em ~30% do topo (visualmente entre
  /// os chips e o título).
  static const _mapCenterLatOffset = 0.002;

  /// Deslocamento de longitude — centra o mapa a OESTE do marker, então o
  /// marker (e o trajeto) aparece à DIREITA do centro da tela (meia-direita).
  /// ~0.0018° em zoom 16 ≈ marker em ~70% da largura.
  static const _mapCenterLngOffset = 0.0018;

  @override
  void didUpdateWidget(covariant _RouteMapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.isEmpty) return;

    final lastPoint = widget.points.last;
    final oldLastPoint = oldWidget.points.isEmpty
        ? null
        : oldWidget.points.last;
    if (oldLastPoint?.lat == lastPoint.lat &&
        oldLastPoint?.lng == lastPoint.lng) {
      return;
    }

    // Quando o PRIMEIRO ponto chega (oldWidget tinha points vazio →
    // build retornava _WaitingForGpsMap, sem FlutterMap), o FlutterMap
    // ainda não foi renderizado neste frame — chamar _mapController.move
    // aqui crasha com "You need to have the FlutterMap widget rendered
    // at least once before using the MapController". Adiar pro próximo
    // frame garante que a árvore já tem o FlutterMap montado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(
          LatLng(
            lastPoint.lat - _mapCenterLatOffset,
            lastPoint.lng - _mapCenterLngOffset,
          ),
          16,
        );
      } catch (_) {
        // Se ainda assim falhar (frame muito apertado), próximo ponto
        // GPS dispara outro didUpdateWidget e tenta de novo.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final latLngs = widget.points.map((p) => LatLng(p.lat, p.lng)).toList();

    // FlutterMap SEMPRE montado pra evitar "MapController before render".
    // Sem fix ainda: center neutro (0,0) com zoom muito baixo — tiles
    // do OSM nesse zoom é só água/grade, fica praticamente invisível
    // atrás do overlay de stats. Quando primeiro fix chega, didUpdateWidget
    // re-centraliza via postFrameCallback.
    final hasFix = latLngs.isNotEmpty;
    final center = hasFix
        ? LatLng(
            latLngs.last.latitude - _mapCenterLatOffset,
            latLngs.last.longitude - _mapCenterLngOffset,
          )
        : const LatLng(0, 0);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasFix ? 16 : 4,
            backgroundColor: palette.surface,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.s6lab.runnin',
          tileBuilder: (context, child, tile) => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -0.2126,
              -0.7152,
              -0.0722,
              0,
              255,
              -0.2126,
              -0.7152,
              -0.0722,
              0,
              255,
              -0.2126,
              -0.7152,
              -0.0722,
              0,
              255,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: child,
          ),
        ),
        if (latLngs.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: latLngs, strokeWidth: 3, color: palette.primary),
            ],
          ),
        if (latLngs.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: latLngs.last,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
        // Sem overlay "AGUARDANDO GPS" — antes ocupava a tela inteira.
        // Pedido do user: mapa fica blank silencioso até primeiro fix
        // (apenas o chip de status no topo já comunica isso). Modal de
        // permissão só aparece se _gpsStatus != ok (vide _ActiveRunViewState).
      ],
    );
  }
}
class _StatsOverlay extends StatelessWidget {
  final RunState state;
  final String initialType;
  final VoidCallback onStart;
  final bool gpsOk;
  final VoidCallback onRetryGps;
  const _StatsOverlay({
    required this.state,
    required this.initialType,
    required this.onStart,
    required this.gpsOk,
    required this.onRetryGps,
  });

  @override
  Widget build(BuildContext context) {
    // UI única pra idle e active (PNG): header brand + 2x2 stats + timer
    // + splits + botões. INICIAR muda só os botões (não troca a tela).
    return _ActiveStatsLayout(
      state: state,
      initialType: initialType,
      gpsOk: gpsOk,
      onStart: onStart,
      onRetryGps: onRetryGps,
      onPauseResume: () {
        final bloc = context.read<RunBloc>();
        if (state.status == RunStatus.paused) {
          bloc.add(ResumeRun());
        } else {
          bloc.add(PauseRun());
        }
      },
      onFinish: () => _finishRun(context, state),
    );
  }

  // Legacy idle layout — removido. Tudo passou pro _ActiveStatsLayout.
  // ignore: unused_element
  Widget _buildLegacy(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final isIdle = state.status == RunStatus.idle ||
        state.status == RunStatus.starting;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            palette.surface,
            palette.surface.withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              initialType.toUpperCase(),
              style: context.runninType.labelMd.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.6,
              ),
            ),
          ),
          // FittedBox protege contra overflow em telas estreitas (ex: 360dp).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              state.formattedDistance,
              style: type.dataXl.copyWith(fontSize: 72),
              maxLines: 1,
              softWrap: false,
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: _StatChip(label: 'PACE', value: state.formattedPace, unit: '/km'),
              ),
              const SizedBox(width: 32),
              Flexible(
                child: _StatChip(
                  label: 'TEMPO',
                  value: state.formattedElapsed,
                  unit: '',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Botão muda: idle/starting → INICIAR; active+ → ABANDONAR + FINALIZAR.
          if (isIdle) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: state.status == RunStatus.starting ? null : onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  disabledBackgroundColor:
                      palette.primary.withValues(alpha: 0.4),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: state.status == RunStatus.starting
                    ? CircularProgressIndicator(
                        color: palette.background,
                        strokeWidth: 2,
                      )
                    : Text(
                        'INICIAR CORRIDA',
                        style: context.runninType.bodyMd.copyWith(
                          color: palette.background,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O tempo só começa ao tocar INICIAR.',
              style: context.runninType.bodyXs.copyWith(
                color: palette.muted,
                height: 1.4,
              ),
            ),
            // Botão "TENTAR LOCALIZAÇÃO": só visível em idle se GPS
            // não-ok. Re-dispara o modal + força refresh — útil quando
            // o user dispensou o popup do navegador.
            if (!gpsOk) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onRetryGps,
                  icon: Icon(Icons.gps_fixed, size: 16, color: context.runninPalette.secondary),
                  label: Text(
                    'TENTAR LOCALIZAÇÃO',
                    style: context.runninType.labelCaps.copyWith(
                      color: context.runninPalette.secondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.runninPalette.secondary.withValues(alpha: 0.55),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<RunBloc>().add(AbandonRun());
                      context.pop();
                    },
                    child: Text(
                      'ABANDONAR',
                      style: type.labelCaps.copyWith(color: palette.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: state.status == RunStatus.completing
                        ? null
                        : () {
                            _finishRun(context, state);
                          },
                    child: state.status == RunStatus.completing
                        ? CircularProgressIndicator(
                            color: palette.background,
                            strokeWidth: 2,
                          )
                        : const Text('FINALIZAR'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _finishRun(BuildContext context, RunState state) async {
    // Indoor (esteira): sem GPS a distância fica 0 — pede o número do
    // painel da esteira, mostra o resumo do que será salvo (km/tempo/pace/
    // data + aviso de imutabilidade) e só então completa. VOLTAR em
    // qualquer etapa mantém a corrida ativa; DESCARTAR abandona.
    if (state.indoor) {
      final distanceM = await _IndoorDistanceDialog.show(context, state);
      if (distanceM == null || !context.mounted) return;
      if (distanceM == _IndoorDistanceDialog.discardSentinel) {
        context.read<RunBloc>().add(AbandonRun());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrida indoor descartada.'),
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/home');
        return;
      }
      final confirmed = await _confirmIndoorSave(context, state, distanceM);
      if (confirmed != true || !context.mounted) return;
      context.read<RunBloc>().add(CompleteRun(manualDistanceM: distanceM));
      return;
    }
    if (state.distanceM >= RunBloc.stationaryDistanceThresholdM) {
      context.read<RunBloc>().add(CompleteRun());
      return;
    }

    // Sem deslocamento → descarta direto, só informa. Antes abria dialog
    // perguntando "salvar mesmo?" — mas se não tem distância, salvar
    // suja os agregados (vide stats com pace 23:06/km) e o user nunca
    // ganha nada com isso. Decisão automática + snackbar.
    context.read<RunBloc>().add(AbandonRun());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrida descartada — sem distância registrada.'),
        duration: Duration(seconds: 3),
      ),
    );
    context.go('/home');
  }

  /// Confirmação do save indoor: mostra exatamente o que será gravado
  /// (distância digitada, tempo, pace derivado e data) + aviso de que a
  /// corrida não poderá ser apagada depois.
  Future<bool?> _confirmIndoorSave(
    BuildContext context,
    RunState state,
    double distanceM,
  ) {
    final palette = context.runninPalette;
    final km = distanceM / 1000.0;
    final paceSecPerKm = km > 0 ? (state.elapsedS / km).round() : 0;
    final pace = km > 0
        ? '${paceSecPerKm ~/ 60}:${(paceSecPerKm % 60).toString().padLeft(2, '0')}/km'
        : '--:--';
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: palette.muted, fontSize: 13)),
              Text(
                value,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('SALVAR CORRIDA INDOOR?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Distância', '${km.toStringAsFixed(2)} km'),
            row('Tempo', state.formattedElapsed),
            row('Pace', pace),
            row('Data', date),
            const SizedBox(height: 12),
            Text(
              'Depois de salva, a corrida entra no seu histórico e não poderá ser apagada.',
              style: TextStyle(color: palette.secondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('VOLTAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONFIRMAR E SALVAR'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, unit;
  const _StatChip({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Column(
      children: [
        Text(label, style: type.labelCaps),
        const SizedBox(height: 4),
        // FittedBox + maxLines/softWrap protegem PACE "--:--/km" e
        // TEMPO "1:02:34" de cortar em telas estreitas.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            maxLines: 1,
            softWrap: false,
            text: TextSpan(
              text: value,
              style: type.dataMd.copyWith(color: palette.primary),
              children: [
                if (unit.isNotEmpty) TextSpan(text: unit, style: type.bodySm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachLiveBanner extends StatelessWidget {
  final String message;
  const _CoachLiveBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.86),
        border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.graphic_eq, size: 16, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: type.bodyMd.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms);
  }
}

/// Layout do active run conforme PNG do design: header brand + grid
/// 2x2 (PACE/DIST/BPM/CAL) + timer central + splits row + botões.
/// Mapa fica embaixo como background (via Stack do _ActiveRunView).
class _ActiveStatsLayout extends StatefulWidget {
  final RunState state;
  final String initialType;
  final bool gpsOk;
  final VoidCallback onStart;
  final VoidCallback onRetryGps;
  final VoidCallback onPauseResume;
  final VoidCallback onFinish;
  const _ActiveStatsLayout({
    required this.state,
    required this.initialType,
    required this.gpsOk,
    required this.onStart,
    required this.onRetryGps,
    required this.onPauseResume,
    required this.onFinish,
  });

  @override
  State<_ActiveStatsLayout> createState() => _ActiveStatsLayoutState();
}

class _ActiveStatsLayoutState extends State<_ActiveStatsLayout> {
  // BPM live agora vem do RunBloc.state.currentBpm — alimentado pelo
  // workoutRealtimeService (HKWorkoutSession iOS / HealthServicesClient
  // Android) a ~1Hz. Substitui o polling de 10s ao plugin `health`.

  String _bpmZone(int? bpm) {
    if (bpm == null) return 'Z—';
    if (bpm < 100) return 'Z1:WARMUP';
    if (bpm < 130) return 'Z2:EASY';
    if (bpm < 150) return 'Z3:AEROBIC';
    if (bpm < 170) return 'Z4:THRESHOLD';
    return 'Z5:VO2';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final state = widget.state;
    final initialType = widget.initialType;
    final runType = state.runType?.isNotEmpty == true ? state.runType! : initialType;
    final paceVal = state.formattedPace == '--:--' ? '--:--' : state.formattedPace;
    // BPM live: vem direto do RunBloc.state.currentBpm — alimentado pelo
    // workoutRealtimeService (~1Hz quando há Watch / Wear OS pareado).
    // Quando state.bpmSourceActive=false (sem samples por >20s), exibimos
    // "—" em cor muted em vez de manter o último valor (que dava sensação
    // de valor mockado quando o wearable desconectava).
    final int? bpm = state.bpmSourceActive ? state.currentBpm : null;
    final kcal = ((state.distanceM / 1000) * 60).round();

    // Pace ACUMULADO por km (tempo total até o km / nº de km), em mm:ss/km.
    String fmtPaceSec(double secPerKm) {
      if (secPerKm <= 0) return '--:--';
      final m = secPerKm ~/ 60;
      final s = (secPerKm % 60).round();
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final cumPaces = <String>[];
    var cumS = 0;
    for (var i = 0; i < state.splits.length; i++) {
      cumS += state.splits[i].durationS;
      cumPaces.add(fmtPaceSec(cumS / (i + 1)));
    }
    // Pace acumulado geral (pro km em andamento): tempo total / distância.
    final overallCumPace = state.distanceM > 0
        ? fmtPaceSec(state.elapsedS / (state.distanceM / 1000))
        : '--:--';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            palette.surface,
            palette.surface.withValues(alpha: 0.85),
            palette.surface.withValues(alpha: 0.40),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.80, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compacto: tipo de corrida.
            Row(
              children: [
                Container(width: 10, height: 10, color: palette.primary),
                const SizedBox(width: 8),
                Text(
                  runType.toUpperCase(),
                  style: type.labelMd.copyWith(
                    color: palette.primary,
                    fontSize: 13,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // PACE + DIST — destaque principal (maiores).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatCell(
                    stat: _GridStat(
                      label: 'PACE',
                      value: paceVal,
                      unit: '/km',
                      valueColor: palette.primary,
                      valueSize: 38,
                    ),
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    stat: _GridStat(
                      label: 'DIST',
                      value: state.formattedDistance.replaceAll('km', '').trim(),
                      unit: 'km',
                      valueColor: palette.secondary,
                      valueSize: 38,
                    ),
                  ),
                ),
              ],
            ),
            Container(height: 1, color: palette.border, margin: const EdgeInsets.symmetric(vertical: 12)),
            // BPM · ELEV · CAL — secundários (menores).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatCell(
                    stat: _GridStat(
                      label: 'BPM',
                      value: bpm?.toString() ?? '—',
                      unit: _bpmZone(bpm),
                      valueColor: bpm != null ? palette.secondary : palette.muted,
                      valueSize: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    stat: _GridStat(
                      label: 'ELEV',
                      value: state.splits
                          .fold<double>(0, (s, sp) => s + (sp.elevationGain ?? 0))
                          .round()
                          .toString(),
                      unit: 'm D+',
                      valueColor: palette.text,
                      valueSize: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    stat: _GridStat(
                      label: 'CAL',
                      value: kcal.toString(),
                      unit: 'KCAL',
                      valueColor: palette.text,
                      valueSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Splits: faixa horizontal (rola só na horizontal), sempre visível.
            if (state.distanceM > 0) ...[
              Row(
                children: [
                  Text(
                    'SPLITS  →',
                    style: type.labelMd.copyWith(
                      color: palette.muted,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                // 86 estourava 7px quando o card mostrava "em andamento"
                // (texto longo + line-height do labelCaps quebra em 2 linhas).
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      state.splits.length < 5 ? 5 : state.splits.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i < state.splits.length) {
                      final s = state.splits[i];
                      // Label 1-based (kmIndex é 0-based); pace ACUMULADO.
                      return _SplitCard(
                        kmLabel: 'KM ${(s.kmIndex + 1).toString().padLeft(2, '0')}',
                        paceLabel: cumPaces[i],
                        speedLabel: '${s.avgSpeedKmh.toStringAsFixed(1)} km/h',
                        done: true,
                        avgBpm: s.avgBpm,
                        maxBpm: s.maxBpm,
                        elevationGain: s.elevationGain,
                        calories: s.calories,
                      );
                    }
                    final kmIdx = i + 1;
                    final currentKm = (state.distanceM / 1000).floor() + 1;
                    final isCurrent = kmIdx == currentKm;
                    return _SplitCard(
                      kmLabel: 'KM ${kmIdx.toString().padLeft(2, '0')}',
                      paceLabel: isCurrent ? overallCumPace : '--:--',
                      speedLabel: isCurrent ? 'em andamento' : '--',
                      done: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Buttons row: idle → INICIAR; active → PAUSAR + FINALIZAR; paused → RETOMAR + FINALIZAR.
            _ButtonsRow(
              isIdle: state.status == RunStatus.idle ||
                  state.status == RunStatus.starting,
              isStarting: state.status == RunStatus.starting,
              isPaused: state.status == RunStatus.paused,
              isCompleting: state.status == RunStatus.completing,
              gpsOk: widget.gpsOk,
              onStart: widget.onStart,
              onRetryGps: widget.onRetryGps,
              onPauseResume: widget.onPauseResume,
              onFinish: widget.onFinish,
            ),
            // Toggle mock GPS (debug-only — invisível em release). Aparece
            // no idle pra setar pace ANTES de iniciar; some quando a run
            // está rolando pra não poluir a UI de stats.
            if (state.status == RunStatus.idle ||
                state.status == RunStatus.starting)
              const _MockGpsToggle(),
          ],
        ),
      ),
    );
  }
}

/// Botão INICIAR que carrega como uma barra de status por 10s (janela pra
/// colocar os fones). Durante o carregamento o texto é "COLOQUE SEUS FONES
/// DE OUVIDO" e o preenchimento cresce da esquerda pra direita. Ao terminar,
/// vira "INICIAR CORRIDA" e o toque inicia a corrida. Tocar antes do fim
/// PULA o carregamento (deixa pronto na hora, sem iniciar).
class _StartButton extends StatefulWidget {
  final bool isStarting;
  final VoidCallback onStart;
  const _StartButton({required this.isStarting, required this.onStart});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_ready) {
          setState(() => _ready = true);
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.isStarting) return;
    if (!_ready) {
      // Pula o carregamento → fica pronto na hora (não inicia ainda).
      _ctrl.stop();
      setState(() => _ready = true);
      return;
    }
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final progress = _ready ? 1.0 : _ctrl.value;
    // Texto claro durante o carregamento (lê bem sobre o trilho escuro);
    // texto na cor base (escuro) quando pronto, sobre o primário cheio.
    final textColor = _ready ? palette.background : palette.text;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isStarting ? null : _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Trilho (parte ainda não carregada): primário esmaecido.
              ColoredBox(color: palette.primary.withValues(alpha: 0.22)),
              // Preenchimento (barra de status): primário cheio crescendo.
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: ColoredBox(color: palette.primary),
                ),
              ),
              Center(
                child: widget.isStarting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: palette.background,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _ready
                            ? 'INICIAR CORRIDA  ↗'
                            : 'COLOQUE SEUS FONES DE OUVIDO',
                        textAlign: TextAlign.center,
                        style: type.labelMd.copyWith(
                          color: textColor,
                          letterSpacing: 1.2,
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

class _ButtonsRow extends StatelessWidget {
  final bool isIdle;
  final bool isStarting;
  final bool isPaused;
  final bool isCompleting;
  final bool gpsOk;
  final VoidCallback onStart;
  final VoidCallback onRetryGps;
  final VoidCallback onPauseResume;
  final VoidCallback onFinish;
  const _ButtonsRow({
    required this.isIdle,
    required this.isStarting,
    required this.isPaused,
    required this.isCompleting,
    required this.gpsOk,
    required this.onStart,
    required this.onRetryGps,
    required this.onPauseResume,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    if (isIdle) {
      return Column(
        children: [
          _StartButton(isStarting: isStarting, onStart: onStart),
          if (!gpsOk) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onRetryGps,
                icon: Icon(Icons.gps_fixed, size: 16, color: palette.secondary),
                label: Text(
                  'TENTAR LOCALIZAÇÃO',
                  style: type.labelMd.copyWith(
                    color: palette.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.secondary.withValues(alpha: 0.55)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onPauseResume,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isPaused ? palette.primary : palette.border,
                ),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                isPaused ? 'RETOMAR' : 'PAUSAR',
                style: type.labelMd.copyWith(
                  color: isPaused ? palette.primary : palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isCompleting ? null : onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.background,
                disabledBackgroundColor: palette.primary.withValues(alpha: 0.4),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: isCompleting
                  ? CircularProgressIndicator(color: palette.background, strokeWidth: 2)
                  : Text(
                      'FINALIZAR  ↗',
                      style: type.labelMd.copyWith(
                        color: palette.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridStat {
  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  /// Tamanho do número. PACE/DIST grandes (38); BPM/ELEV/CAL menores (20).
  final double valueSize;
  const _GridStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    this.valueSize = 30,
  });
}

class _StatCell extends StatelessWidget {
  final _GridStat stat;
  const _StatCell({required this.stat});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.label,
          style: type.labelCaps.copyWith(color: palette.muted, fontSize: 12, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          stat.value,
          style: type.dataMd.copyWith(color: stat.valueColor, fontSize: stat.valueSize, letterSpacing: -0.4),
        ),
        const SizedBox(height: 2),
        Text(
          stat.unit,
          style: type.labelCaps.copyWith(color: palette.muted, fontSize: 11, letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class _SplitCard extends StatelessWidget {
  final String kmLabel;
  /// Pace AGREGADO (médio) do split (mm:ss/km), não o smoothed instantâneo.
  final String paceLabel;
  /// Velocidade média (km/h), ou "em andamento" pra split em curso.
  final String speedLabel;
  final bool done;
  /// TF 75 Fase 10: BPM avg/max + elevação + calorias por split.
  /// Null quando indisponível (sem wearable, split em curso, etc).
  final int? avgBpm;
  final int? maxBpm;
  final double? elevationGain;
  final int? calories;
  const _SplitCard({
    required this.kmLabel,
    required this.paceLabel,
    required this.speedLabel,
    required this.done,
    this.avgBpm,
    this.maxBpm,
    this.elevationGain,
    this.calories,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final accent = done ? palette.secondary : palette.muted;
    final mutedFg = palette.muted.withValues(alpha: 0.7);
    return Container(
      // TF 77 F4: 124→144 + maxLines:1 + ellipsis nos textos pra evitar
      // RenderFlex overflow de 34px (Fase 10 TF 75 enchia card).
      width: 144,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: done ? accent.withValues(alpha: 0.6) : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kmLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelCaps.copyWith(color: accent, fontSize: 11, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          // Pace médio (agregado) — destaque principal do card
          Text(
            paceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelMd.copyWith(
              color: done ? palette.text : mutedFg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // Velocidade média (km/h)
          Text(
            speedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelCaps.copyWith(
              color: mutedFg,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          // TF 75 Fase 10: BPM avg·max + elevação + calorias quando disponíveis.
          if (avgBpm != null || elevationGain != null || calories != null) ...[
            const SizedBox(height: 4),
            if (avgBpm != null)
              Text(
                '♥ $avgBpm${maxBpm != null ? '·max $maxBpm' : ''}',
                style: type.labelCaps.copyWith(
                  color: mutedFg,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            if (elevationGain != null && elevationGain! > 0)
              Text(
                '↑${elevationGain!.toStringAsFixed(0)}m',
                style: type.labelCaps.copyWith(
                  color: mutedFg,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            if (calories != null && calories! > 0)
              Text(
                '${calories}kcal',
                style: type.labelCaps.copyWith(
                  color: mutedFg,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── DEBUG: Mock GPS toggle ─────────────────────────────────────────────────
//
// Renderiza um painel pequeno abaixo do INICIAR pra ligar/desligar o
// mock GPS e ajustar o pace antes de começar. Em release (kDebugMode=false)
// retorna SizedBox.shrink — zero overhead.

class _MockGpsToggle extends StatefulWidget {
  const _MockGpsToggle();

  @override
  State<_MockGpsToggle> createState() => _MockGpsToggleState();
}

class _MockGpsToggleState extends State<_MockGpsToggle> {
  late bool _enabled = mockGpsService.enabled;
  late double _pace = mockGpsService.paceMinKm;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final palette = context.runninPalette;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: _enabled ? palette.primary : palette.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _enabled ? Icons.bug_report : Icons.bug_report_outlined,
                size: 14,
                color: _enabled ? palette.primary : palette.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _enabled
                      ? 'MOCK GPS · ${_pace.toStringAsFixed(1)}min/km'
                      : 'MOCK GPS (DEBUG)',
                  style: context.runninType.labelMd.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: _enabled ? palette.primary : palette.muted,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _enabled,
                  activeThumbColor: palette.primary,
                  onChanged: (v) {
                    setState(() {
                      _enabled = v;
                      mockGpsService.enabled = v;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'PACE',
                  style: context.runninType.labelMd.copyWith(
                    fontSize: 9,
                    color: palette.muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _pace.clamp(3.0, 12.0),
                    min: 3.0,
                    max: 12.0,
                    divisions: 18, // 0.5 min/km steps
                    activeColor: palette.primary,
                    inactiveColor: palette.border,
                    onChanged: (v) {
                      setState(() {
                        _pace = v;
                        mockGpsService.paceMinKm = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Fundo da corrida indoor: dark sólido com ícone sutil de corrida no
/// terço superior — substitui o mapa (sem GPS não há rota; mapa vazio em
/// (0,0) parecia bug).
class _IndoorBackground extends StatelessWidget {
  const _IndoorBackground();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      color: palette.background,
      alignment: const Alignment(0, -0.45),
      child: Icon(
        Icons.directions_run,
        size: 120,
        color: palette.primary.withValues(alpha: 0.08),
      ),
    );
  }
}

/// Dialog do finish indoor: user digita a distância exibida no painel da
/// esteira. Retorna metros; null = VOLTAR (corrida continua ativa);
/// [discardSentinel] = DESCARTAR (caller abandona a run).
class _IndoorDistanceDialog extends StatefulWidget {
  final RunState runState;
  const _IndoorDistanceDialog({required this.runState});

  /// Valor retornado quando o user escolhe DESCARTAR a corrida.
  static const discardSentinel = -1.0;

  static Future<double?> show(BuildContext context, RunState state) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IndoorDistanceDialog(runState: state),
    );
  }

  @override
  State<_IndoorDistanceDialog> createState() => _IndoorDistanceDialogState();
}

class _IndoorDistanceDialogState extends State<_IndoorDistanceDialog> {
  final _controller = TextEditingController();
  double? _parsedKm;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(",", "."));
    // Sanidade: 0.05-100km cobre de teste curto a ultra de esteira.
    setState(() => _parsedKm = (v != null && v >= 0.05 && v <= 100) ? v : null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AlertDialog(
      title: const Text("DISTÂNCIA DA ESTEIRA"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tempo de corrida: ${widget.runState.formattedElapsed}. "
            "Digite a distância que o painel da esteira mostra.",
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: "Distância (km)",
              hintText: "Ex: 5.2",
              suffixText: "km",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(_IndoorDistanceDialog.discardSentinel),
          child: Text(
            "DESCARTAR",
            style: TextStyle(color: palette.secondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("VOLTAR"),
        ),
        ElevatedButton(
          onPressed: _parsedKm == null
              ? null
              : () => Navigator.of(context).pop(_parsedKm! * 1000),
          child: const Text("SALVAR"),
        ),
      ],
    );
  }
}
