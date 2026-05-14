import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/metric_card.dart';

class WeekDetailPage extends StatelessWidget {
  final PlanWeek week;
  final List<PlanSession> sessions;
  final String planId;

  const WeekDetailPage({
    super.key,
    required this.week,
    required this.sessions,
    required this.planId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final orderedSessions = [...sessions]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final totalDistance = orderedSessions.fold<double>(0, (sum, session) => sum + session.distanceKm);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                'SEMANA ${week.weekNumber}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: palette.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppTag(
                          label: week.isRecoveryWeek ? 'RECUPERAÇÃO' : ' TREINO',
                          color: week.isRecoveryWeek
                              ? palette.secondary.withValues(alpha: 0.7)
                              : palette.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _WeekSummary(week: week),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: 'TOTAL KM',
                            value: '${totalDistance.toStringAsFixed(1)}K',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            label: 'SESSÕES',
                            value: '${orderedSessions.length}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SESSÕES DA SEMANA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              ...orderedSessions.map((session) => _WeekSessionRow(
                    session: session,
                    planId: planId,
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  final PlanWeek week;

  const _WeekSummary({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.runninPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foco da Semana',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.runninPalette.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            week.isRecoveryWeek
                ? 'Recuperação ativa com baixa intensidade para reposição energética.'
                : 'Sessões focadas no desenvolvimento de resistência e força.',
            style: TextStyle(
              fontSize: 14,
              color: context.runninPalette.text.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSessionRow extends StatelessWidget {
  final PlanSession session;
  final String planId;

  const _WeekSessionRow({required this.session, required this.planId});

  static const _dayNames = [
    '',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _dayNames[session.dayOfWeek].substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: palette.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayNames[session.dayOfWeek],
                        style: TextStyle(
                          fontSize: 16,
                                    fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.type,
                        style: TextStyle(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${session.distanceKm.toStringAsFixed(1)}K',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.secondary,
                  ),
                ),
              ],
            ),
          ),
          if (session.targetPace != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SmallMetric(label: 'Pace', value: session.targetPace!),
            ),
          if (session.warmupDuration.isNotEmpty || session.cooldownDuration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (session.warmupDuration.isNotEmpty)
                    _SmallMetric(label: 'Aquec', value: session.warmupDuration),
                  if (session.cooldownDuration.isNotEmpty)
                    _SmallMetric(label: 'Descanso', value: session.cooldownDuration),
                ],
              ),
            ),
          if (session.targetHeartRateMin != null && session.targetHeartRateMax != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeartRateZoneCard(
                min: session.targetHeartRateMin!,
                max: session.targetHeartRateMax!,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: AppPanel(
              color: palette.surfaceAlt,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  session.notes.isNotEmpty
                      ? session.notes
                      : 'Sessão de treino conforme plano periodizado.',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.text.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: palette.muted,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartRateZoneCard extends StatelessWidget {
  final int min;
  final int max;

  const _HeartRateZoneCard({required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, size: 16, color: palette.secondary),
          const SizedBox(width: 8),
          Text(
            '${min}-${max} bpm',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.text.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
