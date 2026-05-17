import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/dashboard/domain/dashboard_stats.dart';
import 'package:runnin/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit()..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaTopNav(
            breadcrumb: 'ANALYTICS',
            showBackButton: true,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Métricas, evolução e plano',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2),
                  );
                }
                if (state is DashboardError) {
                  return Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.message, style: type.bodySm),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.read<DashboardCubit>().load(),
                        child: const Text('TENTAR NOVAMENTE'),
                      ),
                    ],
                  ));
                }
                if (state is DashboardLoaded) {
                  return _StatsView(stats: state.stats);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final DashboardStats stats;
  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _StatCard(label: 'CORRIDAS', value: '${stats.totalRuns}')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'DISTÂNCIA',
              value: stats.totalDistanceKm >= 1
                  ? '${stats.totalDistanceKm.toStringAsFixed(1)} km'
                  : '${(stats.totalDistanceKm * 1000).toStringAsFixed(0)} m',
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(label: 'TEMPO TOTAL', value: _formatDuration(stats.totalDurationS))),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'PACE MÉDIO',
              value: stats.avgPace != null ? '${stats.avgPace!}/km' : '--',
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'STREAK',
              value: '${stats.streakDays}d',
              accent: stats.streakDays > 0,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'XP TOTAL',
              value: '${stats.totalXp} xp',
            )),
          ]),
          const SizedBox(height: 8),

          _LevelCard(level: stats.level, totalXp: stats.totalXp),
          const SizedBox(height: 8),

          if (stats.planWeeksTotal > 0) ...[
            _PlanProgressCard(
              weeksCompleted: stats.planWeeksCompleted,
              weeksTotal: stats.planWeeksTotal,
            ),
            const SizedBox(height: 8),
          ],

          if (stats.weeklyDistances.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('DISTÂNCIA SEMANAL', style: type.displaySm.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            _WeeklyChart(weeklyDistances: stats.weeklyDistances),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StatCard({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: accent ? palette.primary.withValues(alpha: 0.4) : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: type.labelCaps),
          const SizedBox(height: 8),
          Text(
            value,
            style: type.dataMd.copyWith(
              color: accent ? palette.primary : palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int level;
  final int totalXp;

  const _LevelCard({required this.level, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final xpForCurrentLevel = (level - 1) * 500;
    final xpInCurrentLevel = totalXp - xpForCurrentLevel;
    final progress = (xpInCurrentLevel / 500).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('NÍVEL', style: type.labelCaps),
            Text('$xpInCurrentLevel / 500 XP', style: type.bodySm),
          ]),
          const SizedBox(height: 8),
          Text('$level', style: type.dataXl.copyWith(color: palette.secondary)),
          const SizedBox(height: 10),
          ClipRect(
            child: Container(
              height: 4,
              color: palette.border,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: palette.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanProgressCard extends StatelessWidget {
  final int weeksCompleted;
  final int weeksTotal;

  const _PlanProgressCard({required this.weeksCompleted, required this.weeksTotal});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final progress = (weeksCompleted / weeksTotal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('PROGRESSO DO PLANO', style: type.labelCaps),
            Text('$weeksCompleted / $weeksTotal semanas', style: type.bodySm),
          ]),
          const SizedBox(height: 10),
          ClipRect(
            child: Container(
              height: 4,
              color: palette.border,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: palette.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<WeeklyDistance> weeklyDistances;
  const _WeeklyChart({required this.weeklyDistances});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final maxDist = weeklyDistances.fold(0.0, (m, w) => w.distanceKm > m ? w.distanceKm : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.041),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyDistances.map((w) {
                final barHeight = maxDist > 0 ? (w.distanceKm / maxDist) * 80 : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (w.distanceKm > 0)
                          Container(
                            height: barHeight,
                            color: palette.primary.withValues(alpha: 0.8),
                          )
                        else
                          Container(height: 4, color: palette.border),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: weeklyDistances.map((w) {
              final label = '${w.weekStart.day}/${w.weekStart.month}';
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: type.labelCaps.copyWith(fontSize: 8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
