import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/domain/entities/run.dart' show GpsPoint;
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/widgets/gps_permission_modal.dart';
import 'package:runnin/shared/widgets/figma/export.dart' show FigmaBadgeUnlockModal;

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
  const ActiveRunPage({
    super.key,
    this.initialType = 'Free Run',
    this.planSessionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<RunBloc, RunState>(
      listenWhen: (_, curr) => curr.status == RunStatus.completed,
      listener: (context, state) {
        final runId = state.completedRun?.id ?? state.runId ?? '';
        if (state.completedRun?.newBadges != null &&
            state.completedRun!.newBadges!.isNotEmpty) {
          _showBadgeUnlockModal(context, state.completedRun!.newBadges!, runId);
        } else {
          context.pushReplacement('/report', extra: runId);
        }
      },
      child: _ActiveRunView(initialType: initialType, planSessionId: planSessionId),
    );
  }

  static void _showBadgeUnlockModal(
    BuildContext context,
    List<String> newBadges,
    String originalRunId,
  ) {
    if (newBadges.isEmpty) return;
    
    final badge = newBadges.first;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FigmaBadgeUnlockModal(
        badgeIcon: Icons.celebration,
        badgeTitle: _getBadgeTitle(badge),
        xpGained: 100,
        message: 'Parabéns! Você desbloqueou um novo badge.',
        onDismiss: () {
          Navigator.of(ctx).pop();
          final remainingBadges = List<String>.from(newBadges)..removeAt(0);
          if (remainingBadges.isEmpty) {
            context.pushReplacement(
              '/report',
              extra: originalRunId,
            );
          } else {
            _showBadgeUnlockModal(context, remainingBadges, originalRunId);
          }
        },
      ),
    );
  }

  static String _getBadgeTitle(String badgeId) {
    switch (badgeId) {
      case 'first_run':
        return 'Primeira Corrida';
      case '距離10':
        return '10km Club';
      case 'streak_7':
        return 'Corredor de 7 Dias';
      case 'distance_50':
        return '50km Master';
      default:
        return badgeId.toUpperCase().replaceAll('_', ' ');
    }
  }
}

class _ActiveRunView extends StatefulWidget {
  final String initialType;
  final String? planSessionId;
  const _ActiveRunView({required this.initialType, this.planSessionId});

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  bool _coachMuted = false;
  bool _coachAudioPlaying = false;
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
      if (!needsAction) return;
      final granted = await GpsPermissionModal.show(
        context,
        blocked: true,
      );
      if (granted && mounted) await _refreshGpsStatus();
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

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: BlocListener<RunBloc, RunState>(
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
                // Background: hero image quando idle (foto do runner igual
                // à home), mapa real durante corrida ativa/paused.
                if (isIdle)
                  const _IdleHeroBackground()
                else
                  _RouteMap(points: state.points),
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
                                      : FigmaColors.brandOrange,
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
                              label: _coachAudioPlaying
                                  ? 'COACH · FALANDO'
                                  : _coachMuted
                                      ? 'COACH · MUTE'
                                      : 'COACH · PRONTO',
                              color: _coachAudioPlaying
                                  ? palette.primary
                                  : _coachMuted
                                      ? palette.muted
                                      : palette.secondary,
                              pulsing: _coachAudioPlaying,
                            ),
                            _StatusChip(
                              icon: Icons.music_note_outlined,
                              label: 'MÚSICA · OFF',
                              color: palette.muted,
                            ),
                            _StatusChip(
                              icon: Icons.favorite_outline,
                              label: 'BPM · —',
                              color: palette.muted,
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
                      // Destrava autoplay dentro do user gesture — sem
                      // isso a saudação Live falha silenciosamente em
                      // Chrome/Safari/Firefox.
                      unlockAudioContext();
                      context
                          .read<RunBloc>()
                          .add(StartRun(
                            type: widget.initialType,
                            planSessionId: widget.planSessionId,
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
          color: palette.background.withValues(alpha: 0.92),
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
        backgroundColor: palette.background.withValues(alpha: 0.82),
        foregroundColor: muted ? palette.muted : palette.primary,
        side: BorderSide(color: palette.border),
      ),
      icon: Icon(muted ? Icons.volume_off_outlined : Icons.volume_up_outlined),
    );
  }
}

class _CoachTalkButton extends StatelessWidget {
  final String runId;
  const _CoachTalkButton({required this.runId});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return IconButton(
      tooltip: 'Falar com o coach',
      onPressed: () => context.push('/coach-live?runId=$runId'),
      style: IconButton.styleFrom(
        backgroundColor: palette.background.withValues(alpha: 0.82),
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.border),
      ),
      icon: const Icon(Icons.chat_bubble_outline),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final List<GpsPoint> points;
  const _RouteMap({required this.points});

  @override
  Widget build(BuildContext context) => _RouteMapBody(points: points);
}

/// Background do estado IDLE — foto do runner (mesma da home, alternada
/// por dia ímpar/par). Usado em vez do mapa quando user ainda não iniciou.
/// Durante corrida ativa, o mapa real substitui esse hero.
class _IdleHeroBackground extends StatelessWidget {
  const _IdleHeroBackground();

  @override
  Widget build(BuildContext context) {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final heroAsset = dayOfYear.isEven
        ? 'assets/img/hero/runner_1.png'
        : 'assets/img/hero/runner_2.png';
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A1A),
          image: DecorationImage(
            image: AssetImage(heroAsset),
            fit: BoxFit.cover,
            onError: (e, _) {
              debugPrint('IDLE_HERO image error: $e');
            },
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
          LatLng(lastPoint.lat - _mapCenterLatOffset, lastPoint.lng),
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
        ? LatLng(latLngs.last.latitude - _mapCenterLatOffset, latLngs.last.longitude)
        : const LatLng(0, 0);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasFix ? 16 : 4,
            backgroundColor: palette.background,
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

class _WaitingForGpsMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.surface, palette.background],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      color: palette.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Aguardando GPS',
                    style: type.displaySm,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Libere a localização no navegador e aguarde o primeiro ponto real para abrir o mapa.',
                    style: type.bodySm.copyWith(
                      color: palette.muted,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
            palette.background,
            palette.background.withValues(alpha: 0.95),
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
                          fontWeight: FontWeight.w500,
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
                  icon: Icon(Icons.gps_fixed, size: 16, color: FigmaColors.brandOrange),
                  label: Text(
                    'TENTAR LOCALIZAÇÃO',
                    style: context.runninType.labelCaps.copyWith(
                      color: FigmaColors.brandOrange,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: FigmaColors.brandOrange.withValues(alpha: 0.55),
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
    if (state.distanceM >= RunBloc.stationaryDistanceThresholdM) {
      context.read<RunBloc>().add(CompleteRun());
      return;
    }

    final choice = await showDialog<_ZeroDistanceChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SALVAR CORRIDA SEM DISTÂNCIA?'),
        content: const Text(
          'Você iniciou a corrida, mas o GPS não registrou deslocamento relevante. Salvar mesmo assim pode interferir nas métricas de pace, volume e progresso.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ZeroDistanceChoice.discard),
            child: const Text('DESCARTAR'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ZeroDistanceChoice.save),
            child: const Text('SALVAR MESMO'),
          ),
        ],
      ),
    );

    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _ZeroDistanceChoice.save:
        context.read<RunBloc>().add(CompleteRun());
        break;
      case _ZeroDistanceChoice.discard:
        context.read<RunBloc>().add(AbandonRun());
        context.go('/home');
        break;
    }
  }
}

enum _ZeroDistanceChoice { save, discard }

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
        color: palette.background.withValues(alpha: 0.86),
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
class _ActiveStatsLayout extends StatelessWidget {
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

  String _bpmZone(int? bpm) {
    if (bpm == null) return 'Z—';
    if (bpm < 100) return 'Z1:WARMUP';
    if (bpm < 130) return 'Z2:EASY';
    if (bpm < 150) return 'Z3:AEROBIC';
    if (bpm < 170) return 'Z4:THRESHOLD';
    return 'Z5:VO2';
  }

  String _typeAsExe(String t) {
    final norm = t.toUpperCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    return '$norm.exe';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final runType = state.runType?.isNotEmpty == true ? state.runType! : initialType;
    final paceVal = state.formattedPace == '--:--' ? '--:--' : state.formattedPace;
    // BPM ainda não capturado no RunState (depende de wearable). Mostra '—'.
    // Kcal estimado simples: distância (km) × 60 (média runner ~60 kcal/km).
    final int? bpm = null;
    final kcal = ((state.distanceM / 1000) * 60).round();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            palette.background,
            palette.background.withValues(alpha: 0.85),
            palette.background.withValues(alpha: 0.40),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.80, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: brand chip + run type como .exe
            Row(
              children: [
                Container(width: 10, height: 10, color: FigmaColors.brandCyan),
                const SizedBox(width: 8),
                Text(
                  'RUN.ACTIVE',
                  style: type.labelMd.copyWith(
                    color: FigmaColors.brandCyan,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                Text(
                  _typeAsExe(runType),
                  style: type.labelMd.copyWith(
                    color: palette.muted,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Grid 2x2 de stats. Cores conforme palette do user:
            // PACE → primary (cyan), DIST → secondary (orange),
            // BPM → secondary (orange), CAL → text default.
            _StatGridRow(
              left: _GridStat(
                index: '01',
                label: 'PACE',
                value: paceVal,
                unit: '/km',
                valueColor: palette.primary,
              ),
              right: _GridStat(
                index: '02',
                label: 'DIST',
                value: state.formattedDistance.replaceAll('km', '').trim(),
                unit: 'km',
                valueColor: palette.secondary,
              ),
            ),
            Container(height: 1, color: palette.border, margin: const EdgeInsets.symmetric(vertical: 14)),
            _StatGridRow(
              left: _GridStat(
                index: '03',
                label: 'BPM',
                value: bpm?.toString() ?? '—',
                unit: _bpmZone(bpm),
                valueColor: palette.secondary,
              ),
              right: _GridStat(
                index: '04',
                label: 'CAL',
                value: kcal.toString(),
                unit: 'KCAL',
                valueColor: palette.text,
              ),
            ),
            const SizedBox(height: 24),

            // Timer central grande
            Text(
              state.formattedElapsed,
              style: type.dataXl.copyWith(fontSize: 64, color: palette.text),
            ),
            const SizedBox(height: 4),
            Text(
              'TEMPO DECORRIDO',
              style: type.labelCaps.copyWith(color: palette.muted, letterSpacing: 1.4),
            ),
            const SizedBox(height: 20),

            // Splits row: SPLITS → + horizontal scroll de km cards
            if (state.distanceM > 0) ...[
              Row(
                children: [
                  Text(
                    'SPLITS  →',
                    style: type.labelMd.copyWith(
                      color: palette.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final kmIdx = i + 1;
                    final reached = (state.distanceM / 1000).floor();
                    final done = kmIdx <= reached;
                    return _SplitCard(
                      kmLabel: 'KM${kmIdx.toString().padLeft(2, '0')}',
                      paceLabel: done ? state.formattedPace : '--:--',
                      statusLabel: done ? 'OK' : 'PEND',
                      done: done,
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Buttons row: idle → INICIAR; active → PAUSAR + FINALIZAR; paused → RETOMAR + FINALIZAR.
            _ButtonsRow(
              isIdle: state.status == RunStatus.idle ||
                  state.status == RunStatus.starting,
              isStarting: state.status == RunStatus.starting,
              isPaused: state.status == RunStatus.paused,
              isCompleting: state.status == RunStatus.completing,
              gpsOk: gpsOk,
              onStart: onStart,
              onRetryGps: onRetryGps,
              onPauseResume: onPauseResume,
              onFinish: onFinish,
            ),
          ],
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isStarting ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: FigmaColors.brandCyan,
                foregroundColor: palette.background,
                disabledBackgroundColor: FigmaColors.brandCyan.withValues(alpha: 0.4),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: isStarting
                  ? CircularProgressIndicator(color: palette.background, strokeWidth: 2)
                  : Text(
                      'INICIAR CORRIDA  ↗',
                      style: type.labelMd.copyWith(
                        color: palette.background,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          if (!gpsOk) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onRetryGps,
                icon: const Icon(Icons.gps_fixed, size: 16, color: FigmaColors.brandOrange),
                label: Text(
                  'TENTAR LOCALIZAÇÃO',
                  style: type.labelMd.copyWith(
                    color: FigmaColors.brandOrange,
                    letterSpacing: 1.2,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: FigmaColors.brandOrange.withValues(alpha: 0.55)),
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
                  color: isPaused ? FigmaColors.brandCyan : palette.border,
                ),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                isPaused ? 'RETOMAR' : 'PAUSAR',
                style: type.labelMd.copyWith(
                  color: isPaused ? FigmaColors.brandCyan : palette.muted,
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
                backgroundColor: FigmaColors.brandCyan,
                foregroundColor: palette.background,
                disabledBackgroundColor: FigmaColors.brandCyan.withValues(alpha: 0.4),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: isCompleting
                  ? CircularProgressIndicator(color: palette.background, strokeWidth: 2)
                  : Text(
                      'FINALIZAR  ↗',
                      style: type.labelMd.copyWith(
                        color: palette.background,
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
  final String index;
  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  const _GridStat({
    required this.index,
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });
}

class _StatGridRow extends StatelessWidget {
  final _GridStat left;
  final _GridStat right;
  const _StatGridRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _StatCell(stat: left)),
        Expanded(child: _StatCell(stat: right)),
      ],
    );
  }
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat.label,
              style: type.labelCaps.copyWith(color: palette.muted, fontSize: 11, letterSpacing: 1.2),
            ),
            Text(
              stat.index,
              style: type.labelCaps.copyWith(color: palette.muted.withValues(alpha: 0.5), fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          stat.value,
          style: type.dataMd.copyWith(color: stat.valueColor, fontSize: 30, letterSpacing: -0.4),
        ),
        const SizedBox(height: 2),
        Text(
          stat.unit,
          style: type.labelCaps.copyWith(color: palette.muted, fontSize: 10, letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class _SplitCard extends StatelessWidget {
  final String kmLabel;
  final String paceLabel;
  final String statusLabel;
  final bool done;
  const _SplitCard({
    required this.kmLabel,
    required this.paceLabel,
    required this.statusLabel,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final accent = done ? FigmaColors.brandOrange : palette.muted;
    return Container(
      width: 84,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kmLabel,
            style: type.labelCaps.copyWith(color: palette.muted, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            paceLabel,
            style: type.labelMd.copyWith(
              color: done ? palette.text : palette.muted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: type.labelCaps.copyWith(
              color: accent,
              fontSize: 9,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
