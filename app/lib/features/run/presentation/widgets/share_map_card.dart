import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

/// Card de share com mapa da rota no fundo e stats sobrepostos.
/// Renderiza num aspect ratio 9:16 (story-friendly) e é capturável via
/// RepaintBoundary -> toImage.
class ShareMapCard extends StatelessWidget {
  final Run run;
  final List<GpsPoint> points;
  const ShareMapCard({super.key, required this.run, required this.points});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final latLng = points
        .map((p) => LatLng(p.lat, p.lng))
        .toList(growable: false);
    final hasRoute = latLng.length >= 2;
    final center = hasRoute
        ? _centroid(latLng)
        : const LatLng(-23.5505, -46.6333); // SP fallback
    final bounds = hasRoute ? LatLngBounds.fromPoints(latLng) : null;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Mapa de fundo
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                initialCameraFit: bounds != null
                    ? CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(40),
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.runnin.app',
                ),
                if (hasRoute)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: latLng,
                        color: palette.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
              ],
            ),

            // Gradient overlay pra contraste do texto
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),

            // Stats overlay
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RUNNIN.AI',
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    run.type.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  _StatRow(label: 'DISTÂNCIA', value: _km(run.distanceM)),
                  const SizedBox(height: 14),
                  _StatRow(label: 'PACE', value: run.avgPace ?? '—'),
                  const SizedBox(height: 14),
                  _StatRow(label: 'TEMPO', value: _duration(run.durationS)),
                  if (run.avgBpm != null) ...[
                    const SizedBox(height: 14),
                    _StatRow(label: 'BPM MÉDIO', value: '${run.avgBpm}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  static String _km(double m) {
    if (m == 0) return '—';
    return '${(m / 1000).toStringAsFixed(2)} km';
  }

  static String _duration(int sec) {
    if (sec == 0) return '—';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "$m:${s.toString().padLeft(2, '0')}";
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
