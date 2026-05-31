import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

/// Timeline km-a-km com instruções literais do coach pra executar a
/// sessão. Cada segment vira um card numerado mostrando faixa de km,
/// fase, pace alvo, tempo e a fala do coach.
///
/// Compartilhado entre o DayDetail (TREINO/PLANO/SEMANA) e o passo de
/// briefing da sessão no prep da corrida.
class ExecutionTimeline extends StatelessWidget {
  final List<PlanSegment> segments;
  const ExecutionTimeline({super.key, required this.segments});

  static const _phaseLabels = {
    'warmup': 'AQUECIMENTO',
    'main': 'PRINCIPAL',
    'interval': 'TIRO',
    'recovery': 'RECUPERAÇÃO',
    'cooldown': 'DESAQUECIMENTO',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered, size: 16, color: palette.primary),
            const SizedBox(width: 8),
            Text(
              'ROTEIRO DA SESSÃO · ${segments.length} fases',
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                color: palette.primary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'O que o coach vai te dizer em cada km. Use o fone — ele acompanha em tempo real.',
          style: context.runninType.bodyXs,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < segments.length; i++)
          _SegmentCard(
            index: i + 1,
            segment: segments[i],
            phaseLabel: _phaseLabels[segments[i].phase.toLowerCase()] ??
                segments[i].phase.toUpperCase(),
            isLast: i == segments.length - 1,
          ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final int index;
  final PlanSegment segment;
  final String phaseLabel;
  final bool isLast;
  const _SegmentCard({
    required this.index,
    required this.segment,
    required this.phaseLabel,
    required this.isLast,
  });

  Color _phaseColor(BuildContext context) {
    final palette = context.runninPalette;
    switch (segment.phase.toLowerCase()) {
      case 'warmup':
        return palette.warning;
      case 'main':
        return palette.primary;
      case 'interval':
        return palette.error;
      case 'recovery':
        return palette.muted;
      case 'cooldown':
        return palette.secondary;
      default:
        return palette.primary;
    }
  }

  String _kmRange() {
    String fmt(double v) =>
        v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return 'KM ${fmt(segment.kmStart)} → ${fmt(segment.kmEnd)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final accent = _phaseColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coluna esquerda: índice + linha conectora
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent, width: 1.0),
                  ),
                  child: Text(
                    '$index',
                    style: context.runninType.labelMd.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: palette.border,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Coluna direita: card com info do segment
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border.all(color: palette.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: accent.withValues(alpha: 0.15),
                          child: Text(
                            phaseLabel,
                            style: context.runninType.labelCaps.copyWith(
                              fontSize: 9,
                              color: accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _kmRange(),
                          style: context.runninType.labelCaps.copyWith(
                            color: palette.muted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    if (segment.targetPace != null ||
                        segment.durationMin != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (segment.targetPace != null) ...[
                            Icon(Icons.speed, size: 11, color: palette.muted),
                            const SizedBox(width: 4),
                            Text(
                              '${segment.targetPace}/km',
                              style: context.runninType.bodyXs.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (segment.durationMin != null) ...[
                            Icon(Icons.timer_outlined,
                                size: 11, color: palette.muted),
                            const SizedBox(width: 4),
                            Text(
                              '~${segment.durationMin!.round()}min',
                              style: context.runninType.bodyXs.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      segment.instruction,
                      style: context.runninType.bodySm.copyWith(
                        color: palette.text,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
