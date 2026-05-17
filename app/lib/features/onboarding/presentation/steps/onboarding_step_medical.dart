import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

const kOnboardingMedicalOptions = [
  'Hipertensao',
  'Diabetes tipo 2',
  'Asma',
  'Historico de AVC',
  'Problemas cardiacos',
  'Lesao no joelho',
  'Lesao no tornozelo',
  'Hernia de disco',
  'Toma anticoagulante',
  'Toma betabloqueador',
  'Toma insulina',
  'Artrose',
  'Fibromialgia',
  'Ansiedade/depressao',
  'Cirurgia recente (<6m)',
];

class OnboardingStepMedical extends StatelessWidget {
  final Set<String> selected;
  final TextEditingController otherController;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddOther;

  const OnboardingStepMedical({
    super.key,
    required this.selected,
    required this.otherController,
    required this.onToggle,
    required this.onAddOther,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final customOptions =
        selected.where((item) => !kOnboardingMedicalOptions.contains(item));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Informações de saúde', style: context.runninType.displayMd),
        const SizedBox(height: 10),
        Text(
          'Opcional, mas importante. Selecione condições relevantes para que o Coach ajuste intensidade, alertas e limites de segurança.',
          style: TextStyle(color: palette.muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        FigmaCoachAIBlock(
          variant: CoachAIBlockVariant.assessment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FigmaCoachAIBreadcrumb(action: 'ANÁLISE'),
              const SizedBox(height: 12),
              Text(
                'Vou avaliar todas as suas informações para montar um programa de treino seguro e personalizado. Se você toma medicação que altera frequência cardíaca, por exemplo, ajusto as zonas de BPM automaticamente.',
                style: context.runninType.bodySm.copyWith(
                  color: palette.text.withValues(alpha: 0.70),
                  height: 21.45 / 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...kOnboardingMedicalOptions.map(
              (option) => FigmaHealthChip(
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
            ),
            ...customOptions.map(
              (option) => FigmaHealthChip(
                label: option,
                selected: true,
                onTap: () => onToggle(option),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _OtherConditionField(
          controller: otherController,
          onAdd: onAddOther,
        ),
      ],
    );
  }
}

/// Campo digitável + botão "+" pra adicionar uma condição custom que
/// não está na lista padrão. Substitui o botão "mockado" que não tinha
/// input visível.
class _OtherConditionField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _OtherConditionField({
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Row(
      children: [
        Expanded(
          child: FigmaFormTextField(
            controller: controller,
            height: 51.5,
            placeholder: 'Outra condição ou medicação…',
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            if (controller.text.trim().isNotEmpty) onAdd();
          },
          child: Container(
            width: 51.5,
            height: 51.5,
            decoration: BoxDecoration(
              color: palette.primary,
              border: Border.all(
                color: palette.primary,
                width: FigmaDimensions.borderUniversal,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '+',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: palette.background,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

