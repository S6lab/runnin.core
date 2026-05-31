import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

/// Card de fechamento do plano. Aparece SOMENTE no final da última semana
/// (no weekly view do training_page e no _WeekTile do plan_detail).
///
/// - RACE (última sessão tem isTarget): mostra distância da prova + data alvo.
/// - FLOW (sem isTarget): mostra "FECHAMENTO DO CICLO" + qtd de semanas.
///
/// Mantém destaque visual forte (primary tint + flag) pra deixar claro que
/// esse marco é o objetivo do plano — diferente das sessões de treino.
class PlanClosingCard extends StatelessWidget {
  final Plan plan;
  final PlanWeek lastWeek;
  const PlanClosingCard({
    super.key,
    required this.plan,
    required this.lastWeek,
  });

  PlanSession? get _targetSession {
    for (final s in lastWeek.sessions) {
      if (s.isTarget) return s;
    }
    return null;
  }

  String? _formatRaceDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final target = _targetSession;
    final isRace = target != null;

    final title = isRace
        ? 'CHEGADA · ${target.type}'
        : 'FECHAMENTO DO PLANO';
    final raceDateLabel = _formatRaceDate(plan.initialDeadlineAt);
    final subtitle = isRace
        ? (raceDateLabel != null
            ? '${target.distanceKm.toStringAsFixed(0)}km · alvo $raceDateLabel'
            : '${target.distanceKm.toStringAsFixed(0)}km — dia da prova')
        : 'Plano completo em ${plan.weeksCount} semanas. '
            'Coach.AI propõe o próximo ciclo no checkpoint final.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.10),
        border: Border.all(color: palette.primary, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag, color: palette.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.labelMd.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: type.bodySm.copyWith(
                    color: palette.text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
