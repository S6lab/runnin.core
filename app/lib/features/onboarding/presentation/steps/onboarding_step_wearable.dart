import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepWearable extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool> onSelect;

  const OnboardingStepWearable({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: '// ASSESSMENT_09'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Conectar wearable?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'Dados de BPM, sono e atividade permitem que o Coach personalize com mais precisão.',
          ),
          const SizedBox(height: 24),
          FigmaSelectionButton(
            label: 'Sim (recomendado)',
            selected: selected == true,
            onTap: () => onSelect(true),
          ),
          const SizedBox(height: 8),
          FigmaSelectionButton(
            label: 'Depois',
            selected: selected == false,
            onTap: () => onSelect(false),
          ),
          const SizedBox(height: 24),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: FigmaColors.brandOrange.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '> COACH.AI',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.65,
                        color: FigmaColors.brandOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tenho tudo que preciso — incluindo sua rotina de sono e horário preferido. Vou calcular a janela metabólica ideal para cada tipo de treino, enviar lembretes de hidratação e preparo nutricional, e sugerir o melhor horário com base no seu padrão de sono.',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 23.1 / 14,
                    color: const Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FigmaCyanInfoBlock(
            icon: Icons.description_outlined,
            title: 'Tem exames médicos recentes?',
            bodyWidget: Text.rich(
              TextSpan(
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 19.2 / 12,
                  color: FigmaColors.textSecondary,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Testes ergométricos, exames de sangue e laudos médicos permitem que eu calibre zonas cardíacas com FC máx real, monitore ferritina e identifique restrições. Após criar seu plano, acesse ',
                  ),
                  TextSpan(
                    text: 'Perfil → Saúde → Exames',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 19.2 / 12,
                      color: FigmaColors.brandCyan,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' para enviar até 5 arquivos por mês (PDF ou foto, máx 10MB).',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
