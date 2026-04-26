import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/core/theme/app_colors.dart';
import 'package:runnin/features/dashboard/domain/dashboard_stats.dart';
import 'package:runnin/features/dashboard/presentation/cubit/dashboard_cubit.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('ANALYTICS', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900, letterSpacing: -0.03)),
            ),
            const SizedBox(height: 20),
            Expanded(child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
                }
                if (state is DashboardError) {
                  return Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.message, style: const TextStyle(color: AppColors.muted)),
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
            )),
          ],
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final DashboardStats stats;
  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid 2x2 de stats principais
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

          // Level
          _LevelCard(level: stats.level, totalXp: stats.totalXp),
          const SizedBox(height: 8),

          // Progresso do plano
          if (stats.planWeeksTotal > 0) ...[
            _PlanProgressCard(
              weeksCompleted: stats.planWeeksCompleted,
              weeksTotal: stats.planWeeksTotal,
            ),
            const SizedBox(height: 8),
          ],

          // Gráfico semanal
          if (stats.weeklyDistances.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('DISTÂNCIA SEMANAL', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: -0.02, fontSize: 13)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: accent ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.1)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: accent ? AppColors.accent : AppColors.text,
              letterSpacing: -0.02)),
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
    final xpForCurrentLevel = (level - 1) * 500;
    final xpInCurrentLevel = totalXp - xpForCurrentLevel;
    final progress = (xpInCurrentLevel / 500).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('NÍVEL', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.1)),
            Text('$xpInCurrentLevel / 500 XP', style: const TextStyle(
                fontSize: 10, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          Text('$level', style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: -0.02)),
          const SizedBox(height: 10),
          ClipRect(
            child: Container(
              height: 4,
              color: AppColors.border,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: AppColors.secondary),
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
    final progress = (weeksCompleted / weeksTotal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('PROGRESSO DO PLANO', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.1)),
            Text('$weeksCompleted / $weeksTotal semanas', style: const TextStyle(
                fontSize: 10, color: AppColors.muted)),
          ]),
          const SizedBox(height: 10),
          ClipRect(
            child: Container(
              height: 4,
              color: AppColors.border,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: AppColors.accent),
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
    final maxDist = weeklyDistances.fold(0.0, (m, w) => w.distanceKm > m ? w.distanceKm : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
                            color: AppColors.accent.withValues(alpha: 0.8),
                          )
                        else
                          Container(height: 4, color: AppColors.border),
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
                child: Text(label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8, color: AppColors.muted)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
