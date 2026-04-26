import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:runnin/core/theme/app_colors.dart';
import 'package:runnin/features/run/domain/entities/run.dart' show GpsPoint;
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';

class ActiveRunPage extends StatelessWidget {
  final String runId;
  const ActiveRunPage({super.key, required this.runId});

  @override
  Widget build(BuildContext context) {
    // RunBloc já foi criado na PrepPage e passado via push — buscamos do contexto pai
    return BlocListener<RunBloc, RunState>(
      listenWhen: (_, curr) => curr.status == RunStatus.completed,
      listener: (context, state) {
        context.pushReplacement('/report', extra: state.completedRun?.id ?? runId);
      },
      child: const _ActiveRunView(),
    );
  }
}

class _ActiveRunView extends StatelessWidget {
  const _ActiveRunView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<RunBloc, RunState>(
        builder: (context, state) => Stack(
          children: [
            // Mapa com rota
            _RouteMap(points: state.points),

            if (state.coachLiveMessage != null && state.coachLiveMessage!.isNotEmpty)
              Positioned(
                top: 56,
                left: 16,
                right: 16,
                child: _CoachLiveBanner(message: state.coachLiveMessage!),
              ),

            // Overlay de dados
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _StatsOverlay(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final List<GpsPoint> points;
  const _RouteMap({required this.points});

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = latLngs.isNotEmpty ? latLngs.last : const LatLng(-23.5505, -46.6333);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        backgroundColor: AppColors.background,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.reniuslab.runnin',
          tileBuilder: (context, child, tile) => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -0.2126, -0.7152, -0.0722, 0, 255,
              -0.2126, -0.7152, -0.0722, 0, 255,
              -0.2126, -0.7152, -0.0722, 0, 255,
              0, 0, 0, 1, 0,
            ]),
            child: child,
          ),
        ),
        if (latLngs.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: latLngs, strokeWidth: 3, color: AppColors.accent),
          ]),
        if (latLngs.isNotEmpty)
          MarkerLayer(markers: [
            Marker(
              point: latLngs.last,
              width: 16, height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
          ]),
      ],
    );
  }
}

class _StatsOverlay extends StatelessWidget {
  final RunState state;
  const _StatsOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [AppColors.background, AppColors.background.withValues(alpha: 0.95), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        children: [
          // Distância principal
          Text(state.formattedDistance, style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900, letterSpacing: -0.04, color: AppColors.text, fontSize: 72,
          )).animate().fadeIn(),

          const SizedBox(height: 16),

          // Pace e tempo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(label: 'PACE', value: state.formattedPace, unit: '/km'),
              const SizedBox(width: 32),
              _StatChip(label: 'TEMPO', value: state.formattedElapsed, unit: ''),
            ],
          ),

          const SizedBox(height: 32),

          // Botões
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.read<RunBloc>().add(AbandonRun());
                  context.pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('ABANDONAR', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: state.status == RunStatus.completing ? null : () {
                  context.read<RunBloc>().add(CompleteRun());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: state.status == RunStatus.completing
                    ? const CircularProgressIndicator(color: AppColors.background, strokeWidth: 2)
                    : const Text('FINALIZAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, unit;
  const _StatChip({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 0.1)),
    const SizedBox(height: 4),
    RichText(text: TextSpan(
      text: value,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent),
      children: [if (unit.isNotEmpty) TextSpan(
        text: unit,
        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.normal),
      )],
    )),
  ]);
}

class _CoachLiveBanner extends StatelessWidget {
  final String message;
  const _CoachLiveBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.86),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.graphic_eq, size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
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
