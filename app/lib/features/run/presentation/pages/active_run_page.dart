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
import 'package:runnin/features/run/presentation/widgets/export.dart';

class ActiveRunPage extends StatelessWidget {
  final String runId;
  const ActiveRunPage({super.key, required this.runId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RunBloc, RunState>(
      listenWhen: (_, curr) => curr.status == RunStatus.completed,
      listener: (context, state) {
        context.pushReplacement(
          '/report',
          extra: state.completedRun?.id ?? runId,
        );
      },
      child: const _ActiveRunView(),
    );
  }
}

class _ActiveRunView extends StatefulWidget {
  const _ActiveRunView();

  @override
  State<_ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<_ActiveRunView> {
  bool _coachMuted = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: BlocListener<RunBloc, RunState>(
        listenWhen: (prev, curr) =>
            prev.coachAudioBase64 != curr.coachAudioBase64 &&
            (curr.coachAudioBase64?.isNotEmpty ?? false),
        listener: (context, state) {
          if (_coachMuted) return;
          playCoachAudio(
            state.coachAudioBase64!,
            mimeType: state.coachAudioMimeType ?? 'audio/mpeg',
            volume: 1.0,
            maxDurationMs: 3000,
          );
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
                  child: _CoachMuteButton(
                    muted: _coachMuted,
                    onTap: () => setState(() => _coachMuted = !_coachMuted),
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
            style: context.runninType.dataXl.copyWith(fontSize: 72),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RunMetricCell(label: 'PACE', value: state.formattedPace, unit: '/km'),
              const SizedBox(width: 16),
              RunMetricCell(label: 'TEMPO', value: state.formattedElapsed, unit: ''),
            ],
          ),

          const SizedBox(height: 32),

          ZoneBar(proportions: [0.2, 0.2, 0.2, 0.2, 0.2]),

          const SizedBox(height: 16),

          SplitCard(kmLabel: 'KM01', time: '5:48'),

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
                    style: context.runninType.labelCaps.copyWith(color: palette.muted),
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
