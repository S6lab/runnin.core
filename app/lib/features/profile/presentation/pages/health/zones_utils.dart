import 'package:flutter/material.dart';

class HealthZone {
  const HealthZone({
    required this.number,
    required this.label,
    required this.description,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    this.pctTime = 0,
  });

  final int number;
  final String label;
  final String description;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final double pctTime;

  factory HealthZone.fromKarvonen({
    required int restingBpm,
    required int maxBpm,
    required double intensityPercent,
  }) {
    final karvonen = (maxBpm - restingBpm) * intensityPercent + restingBpm;
    return HealthZone(
      number: 1,
      label: 'Z$intensityPercent',
      description: '',
      minBpm: karvonen.round(),
      maxBpm: karvonen.round(),
      color: const Color(0xFF4D7DFF),
    );
  }
}

List<HealthZone> computeHealthZones({
  required int restingBpm,
  required int maxBpm,
}) {
  return [
    HealthZone(
      number: 1,
      label: 'Z1 — Recuperação',
      description: 'Intensidade leve para recuperação ativa e endurance. Queima Gordura com baixo risco de lesão.',
      minBpm: (restingBpm + (maxBpm - restingBpm) * 0.50).round(),
      maxBpm: (restingBpm + (maxBpm - restingBpm) * 0.60).round(),
      color: const Color(0xFF4D7DFF),
    ),
    HealthZone(
      number: 2,
      label: 'Z2 — Aeróbico Base',
      description: 'Base aerobic com foco em endurance e eficiência cardíaca. Melhora a capacidade aerobic de longa duração.',
      minBpm: (restingBpm + (maxBpm - restingBpm) * 0.60).round(),
      maxBpm: (restingBpm + (maxBpm - restingBpm) * 0.70).round(),
      color: const Color(0xFF25C56B),
    ),
    HealthZone(
      number: 3,
      label: 'Z3 — Tempo',
      description: 'Intensidade moderada para progressão de stamina. Desenvolve potência aerobic e limiar.',
      minBpm: (restingBpm + (maxBpm - restingBpm) * 0.70).round(),
      maxBpm: (restingBpm + (maxBpm - restingBpm) * 0.80).round(),
      color: const Color(0xFFF3BF31),
    ),
    HealthZone(
      number: 4,
      label: 'Z4 — Limiar',
      description: 'Intensidade alta perto do limiar lactato. Melhora tolerância ao esforço intenso.',
      minBpm: (restingBpm + (maxBpm - restingBpm) * 0.80).round(),
      maxBpm: (restingBpm + (maxBpm - restingBpm) * 0.90).round(),
      color: const Color(0xFFFF6E40),
    ),
    HealthZone(
      number: 5,
      label: 'Z5 — VO2 Max',
      description: 'Intensidade máxima para aumento de VO2 max e potência. Treinos curtos de alta intensidade.',
      minBpm: (restingBpm + (maxBpm - restingBpm) * 0.90).round(),
      maxBpm: (restingBpm + (maxBpm - restingBpm) * 1.00).round(),
      color: const Color(0xFFFF3B46),
    ),
  ];
}
