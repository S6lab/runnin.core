import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/metric_card.dart';

class XpLevelCard extends StatelessWidget {
  final List<Run> runs;
  const XpLevelCard({
    super.key,
    required this.runs,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final totalXp = runs.fold<int>(0, (s, r) => s + (r.xpEarned ?? 0));
    final level = (totalXp / 500).floor() + 1;
    final xpInLevel = totalXp - (level - 1) * 500;
    final progress = (xpInLevel / 500).clamp(0.0, 1.0);

    final rules = [
      ('Completar corrida', '+50–120'),
      ('Atingir pace alvo', '+20'),
      ('Manter streak', '+10/dia'),
      ('Novo badge', '+30'),
      ('Compartilhar card', '+5'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NÍVEL & XP', style: type.displayMd),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border, width: 1.041),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('$level', style: type.dataXl.copyWith(color: palette.primary)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Corredor', style: type.labelMd),
                  Text('$xpInLevel / 500 XP', style: type.bodySm),
                ]),
              ]),
              const SizedBox(height: 12),
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
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: MetricCard(label: 'XP TOTAL', value: '$totalXp')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'CORRIDAS', value: '${runs.length}')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'NÍVEL', value: '$level', accentColor: palette.primary)),
        ]),
        const SizedBox(height: 20),
        ...rules.map((rule) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rule.$1, style: type.bodyMd),
              Text(rule.$2, style: type.labelMd.copyWith(color: palette.primary)),
            ],
          ),
        )),
      ],
    );
  }
}
