import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  const ActiveRunPage({super.key, this.initialType = 'Free Run'});

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
      child: _ActiveRunView(initialType: initialType),
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
  const _ActiveRunView({required this.initialType});

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  bool _coachMuted = false;
  bool _coachAudioPlaying = false;
  _GpsStatus _gpsStatus = _GpsStatus.unknown;

  @override
  void initState() {
    super.initState();
    _refreshGpsStatus();
    // Modal de GPS só abre AUTOMATICAMENTE se status != ok. Antes abria
    // em TODA entrada idle, criando UX hostil (modal repetido, possível
    // loop em rebuild). Chip retry continua disponível pra abrir manual.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Aguarda _refreshGpsStatus terminar — sem isso o status ainda
      // é unknown e o modal abriria sempre.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (_gpsStatus == _GpsStatus.ok) return;
      final granted = await GpsPermissionModal.show(
        context,
        blocked: _gpsStatus == _GpsStatus.denied || _gpsStatus == _GpsStatus.off,
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
        listenWhen: (_, curr) =>
            curr.coachAudioBase64 != null && curr.coachAudioBase64!.isNotEmpty,
        listener: (context, state) {
          if (_coachMuted) return;
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
                _RouteMap(points: state.points),
                if (state.coachLiveMessage != null &&
                    state.coachLiveMessage!.isNotEmpty)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    child: _CoachLiveBanner(message: state.coachLiveMessage!),
                  ),
                // Status chips topo-esquerda: GPS, COACH, MÚSICA, WEARABLE.
                Positioned(
                  top: 12,
                  left: 14,
                  right: 80,
                  child: SafeArea(
                    child: Wrap(
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
                                // Mostra contagem de points pra ficar VISÍVEL
                                // que tá vivo (não estático).
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
                      ],
                    ),
                  ),
                ),
                // Mute + Talk no canto superior direito (apenas em active).
                if (!isIdle)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: SafeArea(
                      child: Row(
                        children: [
                          _CoachTalkButton(runId: state.runId ?? ''),
                          const SizedBox(width: 8),
                          Stack(
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
                          .add(StartRun(type: widget.initialType));
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
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 10,
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

class _RouteMapBody extends StatefulWidget {
  final List<GpsPoint> points;
  const _RouteMapBody({required this.points});

  @override
  State<_RouteMapBody> createState() => _RouteMapBodyState();
}

class _RouteMapBodyState extends State<_RouteMapBody> {
  final _mapController = MapController();

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

    _mapController.move(LatLng(lastPoint.lat, lastPoint.lng), 16);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final latLngs = widget.points.map((p) => LatLng(p.lat, p.lng)).toList();
    if (latLngs.isEmpty) {
      return _WaitingForGpsMap();
    }

    final center = latLngs.last;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        backgroundColor: palette.background,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.reniuslab.runnin',
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
          if (isIdle)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                initialType.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          // FittedBox protege contra overflow em telas estreitas (ex: 360dp).
          // Sem isso, "12.34km" pode cortar.
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
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.4,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O tempo só começa ao tocar INICIAR.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
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
                    style: TextStyle(
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
        title: const Text('Salvar corrida sem distância?'),
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
