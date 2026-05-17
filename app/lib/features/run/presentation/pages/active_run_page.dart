import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart' show GpsPoint;
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/shared/widgets/figma/export.dart' show FigmaBadgeUnlockModal;

class ActiveRunPage extends StatelessWidget {
  final String runId;
  const ActiveRunPage({super.key, required this.runId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RunBloc, RunState>(
      listenWhen: (_, curr) => curr.status == RunStatus.completed,
      listener: (context, state) {
        if (state.completedRun?.newBadges != null &&
            state.completedRun!.newBadges!.isNotEmpty) {
          _showBadgeUnlockModal(context, state.completedRun!.newBadges!, runId);
        } else {
          context.pushReplacement(
            '/report',
            extra: state.completedRun?.id ?? runId,
          );
        }
      },
      child: _ActiveRunView(runId: runId),
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
  final String runId;
  const _ActiveRunView({required this.runId});

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  bool _coachMuted = false;
  bool _coachAudioPlaying = false;

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
          // Sem cap de duração: o cap de 3s cortava áudio do TTS estático
          // no meio (efeito "travado no nome"). Tamanho do cue é controlado
          // pelo prompt do server (frases curtas).
          playCoachAudio(
            state.coachAudioBase64!,
            mimeType: state.coachAudioMimeType ?? 'audio/mpeg',
            volume: 1.0,
          ).then((_) => setState(() => _coachAudioPlaying = true));
        },
        child: BlocBuilder<RunBloc, RunState>(
          builder: (context, state) => Stack(
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

              Positioned(
                top: 12,
                right: 14,
                child: SafeArea(
                  child: Row(
                    children: [
                      _CoachTalkButton(runId: widget.runId),
                      const SizedBox(width: 8),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _CoachMuteButton(
                            muted: _coachMuted,
                            onTap: () => setState(() => _coachMuted = !_coachMuted),
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
                child: _StatsOverlay(state: state),
              ),
            ],
          ),
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
  const _StatsOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

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
          Text(
            state.formattedDistance,
            style: type.dataXl.copyWith(fontSize: 72),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(label: 'PACE', value: state.formattedPace, unit: '/km'),
              const SizedBox(width: 32),
              _StatChip(
                label: 'TEMPO',
                value: state.formattedElapsed,
                unit: '',
              ),
            ],
          ),

          const SizedBox(height: 32),

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
        RichText(
          text: TextSpan(
            text: value,
            style: type.dataMd.copyWith(color: palette.primary),
            children: [
              if (unit.isNotEmpty) TextSpan(text: unit, style: type.bodySm),
            ],
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
