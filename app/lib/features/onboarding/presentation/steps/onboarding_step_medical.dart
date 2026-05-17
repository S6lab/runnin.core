import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_shared.dart';
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepCode('ASSESSMENT_04'),
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
          _DashedAddButton(
            controller: otherController,
            onAdd: onAddOther,
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _DashedAddButton({
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.text.trim().isNotEmpty) {
          onAdd();
        }
      },
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: FigmaColors.borderDefault,
          strokeWidth: FigmaDimensions.borderUniversal,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: context.runninPalette.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Adicionar outra condição ou medicação',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedBorderPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
