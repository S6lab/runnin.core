import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Liga a pré-jornada de assessment na criação do plano. Fica `false` até a
/// rota /assessment-run existir (Fase C) — a tela já está pronta atrás da
/// flag pra ligar sem refactor.
const bool kAssessmentRunEnabled = false;

/// Pré-jornada do wizard: oferece a corrida de avaliação ANTES da intro.
/// [CORRER AGORA] → /assessment-run (coach mede ritmo real; wizard prefilla
/// capacidade com selo "medido"). O botão CONTINUAR do wizard funciona como
/// "PREFIRO INFORMAR" (capacity manual).
class StepAssessmentOffer extends StatelessWidget {
  final VoidCallback onRunNow;

  const StepAssessmentOffer({super.key, required this.onRunNow});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// AVALIAÇÃO'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Quer começar com uma corrida de avaliação?'),
        const SizedBox(height: 12),
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
            label: const Text('CORRER AGORA /'),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Sem tempo agora? Toca CONTINUAR e informa sua capacidade '
          'manualmente — dá pra fazer a avaliação depois.',
          style: type.bodySm.copyWith(color: palette.muted, height: 1.5),
        ),
      ],
    );
  }
}
