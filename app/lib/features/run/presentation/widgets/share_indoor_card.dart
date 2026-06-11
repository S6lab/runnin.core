import 'package:flutter/material.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

/// Card de share pra corrida INDOOR (esteira) — substitui o ShareMapCard
/// quando não há rota GPS. Visual inspirado nos badges: emblema central
/// com moldura, lockup INDOOR RUN, local (cidade do device) e data, com
/// os mesmos stats do card de mapa. Capturável via RepaintBoundary.
class ShareIndoorCard extends StatelessWidget {
  final Run run;
  final double aspectRatio;
  /// Cidade do device (locationWeatherController.city) — best-effort,
  /// null omite a linha de local.
  final String? city;
  const ShareIndoorCard({
    super.key,
    required this.run,
    this.aspectRatio = 9 / 16,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRect(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF11161D), Color(0xFF1E2630)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Marca d'água sutil de corredor no fundo (eco do estado
              // indoor da ActiveRunPage).
              Align(
                alignment: const Alignment(1.2, -0.9),
                child: Icon(
                  Icons.directions_run,
                  size: 220,
                  color: palette.primary.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RUNNIN.AI',
                      style: type.labelMd.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      run.type.toUpperCase(),
                      style: type.bodyMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    // Emblema central estilo badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 22),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fitness_center_outlined,
                              size: 44,
                              color: palette.primary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'INDOOR RUN',
                              style: type.labelCaps.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _subtitle(),
                              textAlign: TextAlign.center,
                              style: type.bodyXs.copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
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
      ),
    );
  }

  /// "ESTEIRA · SÃO PAULO · 11 JUN 2026" (cidade omitida quando null).
  String _subtitle() {
    final parts = <String>['ESTEIRA'];
    final c = city?.trim();
    if (c != null && c.isNotEmpty) parts.add(c.toUpperCase());
    final date = _formatDate(run.createdAt);
    if (date != null) parts.add(date);
    return parts.join(' · ');
  }

  static const _months = [
    'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
    'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
  ];

  static String? _formatDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
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
          style: context.runninType.labelCaps.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.runninType.displayMd.copyWith(
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
