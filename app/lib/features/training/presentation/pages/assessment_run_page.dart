import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Corrida de AVALIAÇÃO — escolha do alvo em km. SEM paywall: freemium roda
/// com TelemetryTts, premium com coach Live (decidido pelo isPremium no
/// start). O resultado medido vira capacidade no profile e prefilla o
/// wizard de criação de plano com selo "medido".
class AssessmentRunPage extends StatefulWidget {
  const AssessmentRunPage({super.key});

  @override
  State<AssessmentRunPage> createState() => _AssessmentRunPageState();
}

class _AssessmentRunPageState extends State<AssessmentRunPage> {
  static const _options = <double>[1, 2, 3, 5, 8, 10];
  double _targetKm = 3;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(86, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('< VOLTAR'),
              ),
              const SizedBox(height: 24),
              const FigmaAssessmentLabel(text: '// CORRIDA DE AVALIAÇÃO'),
              const SizedBox(height: 14),
              const FigmaAssessmentHeading(text: 'Quantos km você topa correr agora?'),
              const SizedBox(height: 10),
              FigmaAssessmentDescription(
                text: 'Corre constante e confortável — o coach mede seu ritmo '
                    'real e usa o resultado pra calibrar seu plano. Não é teste '
                    'de velocidade.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final km in _options)
                    InkWell(
                      onTap: () => setState(() => _targetKm = km),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: _targetKm == km
                              ? palette.primary.withValues(alpha: 0.12)
                              : palette.surface,
                          border: Border.all(
                            color: _targetKm == km
                                ? palette.primary
                                : palette.border,
                          ),
                        ),
                        child: Text(
                          '${km.toStringAsFixed(0)} KM',
                          style: type.labelMd.copyWith(
                            color: _targetKm == km
                                ? palette.primary
                                : palette.text,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Na dúvida, 3km já dá uma leitura boa do seu ritmo.',
                style: type.bodySm.copyWith(color: palette.muted),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/run', extra: {
                      'type': 'Avaliação',
                      'assessmentTargetKm': _targetKm,
                      'isPremium': subscriptionController.isPro,
                    });
                  },
                  child: const Text('CORRER AGORA /'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
