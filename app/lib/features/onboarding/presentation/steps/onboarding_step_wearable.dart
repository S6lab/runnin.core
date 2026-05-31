import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
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
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Sincronizar dados de saúde?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'A gente lê BPM, sono e atividade da Apple Health (iOS) ou do '
                'Google Health Connect (Android) — o que o seu relógio já '
                'envia pra essas plataformas. Não conectamos ao dispositivo direto.',
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
                      color: context.runninPalette.secondary.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '> COACH.AI',
                      style: context.runninType.bodyXs.copyWith(
                        letterSpacing: 1.65,
                        color: context.runninPalette.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tenho tudo que preciso — incluindo sua rotina de sono e horário preferido. Vou calcular a janela metabólica ideal para cada tipo de treino, enviar lembretes de hidratação e preparo nutricional, e sugerir o melhor horário com base no seu padrão de sono.',
                  style: context.runninType.bodyMd.copyWith(
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
                style: context.runninType.bodySm.copyWith(
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
                    style: context.runninType.labelMd.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 19.2 / 12,
                      color: context.runninPalette.primary,
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
