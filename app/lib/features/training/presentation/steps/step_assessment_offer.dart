import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart'
    show LastAssessment;
import 'package:runnin/shared/widgets/figma/export.dart';

/// Pré-jornada de assessment na criação do plano. Ligada na Fase C junto
/// com a rota /assessment-run (medição end-to-end).
const bool kAssessmentRunEnabled = true;

/// Pré-jornada do wizard: oferece a corrida de avaliação ANTES da intro.
/// [CORRER AGORA] → /assessment-run (coach mede ritmo real; wizard prefilla
/// capacidade com selo "medido"). O botão CONTINUAR do wizard funciona como
/// "PREFIRO INFORMAR" (capacity manual).
class StepAssessmentOffer extends StatelessWidget {
  final VoidCallback onRunNow;
  /// Última avaliação feita (do profile). Null = nunca fez. Quando
  /// presente, a tela vira "refazer ou seguir com a última" — gerar plano
  /// novo (abandono/conclusão) não força re-correr.
  final LastAssessment? lastAssessment;

  const StepAssessmentOffer({
    super.key,
    required this.onRunNow,
    this.lastAssessment,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final a = lastAssessment;
    final at = a != null ? DateTime.tryParse(a.at) : null;
    final ageDays = at != null ? DateTime.now().difference(at).inDays : null;
    final stale = ageDays != null && ageDays > 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// AVALIAÇÃO'),
        const SizedBox(height: 14),
        FigmaAssessmentHeading(
          text: a == null
              ? 'Quer começar com uma corrida de avaliação?'
              : 'Refazer sua avaliação?',
        ),
        const SizedBox(height: 12),
        if (a != null && at != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(
                color: stale ? palette.border : palette.primary.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              'ÚLTIMA AVALIAÇÃO · ${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}\n'
              '${a.completedKm.toStringAsFixed(1)}km a ${a.paceMinKm}/km'
              '${a.avgBpm != null ? ' · FC média ${a.avgBpm}' : ''}',
              style: type.bodySm.copyWith(color: palette.text, height: 1.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stale
                ? 'Faz mais de 2 semanas — seu ritmo pode ter mudado. '
                    'Recomendo refazer pra calibrar o plano novo.'
                : 'Avaliação recente: pode seguir com ela (CONTINUAR) ou '
                    'refazer se sentir que o ritmo mudou.',
            style: type.bodyMd.copyWith(color: palette.text, height: 1.5),
          ),
        ] else
          Text(
            'O coach mede seu ritmo real numa corrida curta e o plano sai mais '
            'preciso — sem chute de capacidade.',
            style: type.bodyMd.copyWith(color: palette.text, height: 1.55),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onRunNow,
            icon: const Icon(Icons.directions_run),
            label: Text(a == null ? 'CORRER AGORA /' : 'REFAZER AVALIAÇÃO /'),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          a == null
              ? 'Sem tempo agora? Toca CONTINUAR e informa sua capacidade '
                  'manualmente — dá pra fazer a avaliação depois.'
              : 'CONTINUAR usa a última avaliação como capacidade medida.',
          style: type.bodySm.copyWith(color: palette.muted, height: 1.5),
        ),
      ],
    );
  }
}
