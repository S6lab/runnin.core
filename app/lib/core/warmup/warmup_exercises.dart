import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WarmupExercise {
  final IconData icon;
  final String title;
  final String reps;
  final String description;

  const WarmupExercise({
    required this.icon,
    required this.title,
    required this.reps,
    required this.description,
  });
}

const _iconMap = <String, IconData>{
  'directions_walk': Icons.directions_walk,
  'accessibility_new': Icons.accessibility_new,
  'self_improvement': Icons.self_improvement,
  'directions_run': Icons.directions_run,
  'swap_vert': Icons.swap_vert,
  'rotate_right': Icons.rotate_right,
  'straighten': Icons.straighten,
};

const _typeKeyMap = <String, String>{
  'Easy Run': 'easy_run',
  'Intervalado': 'interval',
  'Tempo Run': 'tempo',
  'Long Run': 'long_run',
  'Free Run': 'easy_run',
};

Map<String, List<WarmupExercise>>? _cache;

Future<List<WarmupExercise>> loadWarmupExercises(String runType) async {
  _cache ??= await _loadAll();
  final key = _typeKeyMap[runType] ?? 'easy_run';
  return _cache![key] ?? _cache!['easy_run'] ?? const [];
}

Future<Map<String, List<WarmupExercise>>> _loadAll() async {
  final raw = await rootBundle.loadString('assets/warmup_exercises.json');
  final data = json.decode(raw) as Map<String, dynamic>;
  final result = <String, List<WarmupExercise>>{};
  for (final entry in data.entries) {
    final items = (entry.value as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      return WarmupExercise(
        icon: _iconMap[m['icon']] ?? Icons.fitness_center,
        title: m['title'] as String,
        reps: m['reps'] as String,
        description: m['description'] as String,
      );
    }).toList();
    result[entry.key] = items;
  }
  return result;
}
