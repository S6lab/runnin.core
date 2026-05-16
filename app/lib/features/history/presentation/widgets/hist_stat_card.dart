import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class HistStatCard extends StatelessWidget {
  final List<Run> runs;
  const HistStatCard({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(runs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(children: [
          Expanded(
            child: FigmaHistStatCard(
              label: 'CORRIDAS',
              value: '${stats.count}',
              valueColor: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FigmaHistStatCard(
              label: 'VOLUME',
              value: stats.totalKm.toStringAsFixed(1),
              unit: 'km',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FigmaHistStatCard(
              label: 'TEMPO',
              value: stats.totalTimeLabel,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FigmaHistStatCard(
              label: 'PACE MÉD.',
              value: stats.avgPaceLabel,
              unit: '/km',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FigmaHistStatCard(
              label: 'STREAK',
              value: '${stats.streakDays}',
              unit: 'd',
              valueColor: stats.streakDays > 2
                  ? FigmaColors.brandOrange
                  : FigmaColors.textPrimary,
            ),
          ),
           const SizedBox(width: 8),
           Expanded(
             child: FigmaHistStatCard(
               label: 'XP',
               value: '${stats.totalXp}',
               valueColor: FigmaColors.brandCyan,
             ),
           ),
         ]),
         const SizedBox(height: 8),
         Row(children: [
           Expanded(
             child: FigmaHistStatCard(
               label: 'BPM MÉD.',
               value: stats.avgBpm?.toString() ?? '--',
               unit: 'BPM',
             ),
           ),
         ]),
      ],
    );
  }

  _HistoryStats _computeStats(List<Run> runs) {
    if (runs.isEmpty) return _HistoryStats.empty();

    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));

    int? avgPaceSec;
    final runsWithPace = runs.where((r) => r.avgPace != null).toList();
    if (runsWithPace.isNotEmpty) {
      final paceSecsTotal = runsWithPace.fold<int>(0, (s, r) {
        final parts = r.avgPace!.split(':');
        if (parts.length != 2) return s;
        final m = int.tryParse(parts[0]) ?? 0;
        final sec = int.tryParse(parts[1]) ?? 0;
        return s + m * 60 + sec;
      });
      avgPaceSec = paceSecsTotal ~/ runsWithPace.length;
    }

    final avgPaceLabel = avgPaceSec == null
        ? '--:--'
        : '${avgPaceSec ~/ 60}:${(avgPaceSec % 60).toString().padLeft(2, '0')}';

    final runDays = runs.map((r) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }).whereType<DateTime>().toSet().toList()..sort();

    int streak = 0;
    DateTime? prev;
    for (final day in runDays.reversed) {
      if (prev == null || prev.difference(day).inDays == 1) {
        streak++;
        prev = day;
      } else {
        break;
      }
    }

    final totalMin = totalS ~/ 60;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    final totalTimeLabel =
        h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';

    final avgBpm = _computeAvgBpm(runs);

    return _HistoryStats(
      count: runs.length,
      totalKm: totalDistM / 1000,
      totalTimeLabel: totalTimeLabel,
      avgPaceLabel: avgPaceLabel,
      streakDays: streak,
      totalXp: totalXp,
      avgBpm: avgBpm,
      benchmarkPercentile: _computeBenchmarkPercentile(runs),
    );
  }

  static int? _computeAvgBpm(List<Run> runs) {
    final runsWithBpm = runs.where((r) => r.avgBpm != null).toList();
    if (runsWithBpm.isEmpty) return null;
    final totalBpm = runsWithBpm.fold<int>(0, (s, r) => s + (r.avgBpm ?? 0));
    return totalBpm ~/ runsWithBpm.length;
  }

  static double _computeBenchmarkPercentile(List<Run> runs) {
    if (runs.isEmpty) return 0;
    
    final totalDistM = runs.fold<double>(0.0, (s, r) => s + r.distanceM);
    final totalS = runs.fold<int>(0, (s, r) => s + r.durationS);
    
    final avgSpeedMps = totalDistM / totalS;
    final avgKmph = avgSpeedMps * 3.6;
    
    if (avgKmph < 8) return 10;
    if (avgKmph < 9) return 25;
    if (avgKmph < 10) return 45;
    if (avgKmph < 11) return 65;
    if (avgKmph < 12) return 80;
    return 95;
  }
}

class _HistoryStats {
  final int count;
  final double totalKm;
  final String totalTimeLabel;
  final String avgPaceLabel;
  final int streakDays;
  final int totalXp;
  final int? avgBpm;
  final double benchmarkPercentile;

  const _HistoryStats({
    required this.count,
    required this.totalKm,
    required this.totalTimeLabel,
    required this.avgPaceLabel,
    required this.streakDays,
    required this.totalXp,
    required this.avgBpm,
    required this.benchmarkPercentile,
  });

  factory _HistoryStats.empty() => const _HistoryStats(
        count: 0,
        totalKm: 0,
        totalTimeLabel: '0m',
        avgPaceLabel: '--:--',
        streakDays: 0,
        totalXp: 0,
        avgBpm: null,
        benchmarkPercentile: 0,
      );
}
