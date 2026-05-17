import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class OnboardingIntroSlide {
  final String code;
  final String number;
  final String title;
  final String body;
  final List<OnboardingIntroFeature> features;

  const OnboardingIntroSlide({
    required this.code,
    required this.number,
    required this.title,
    required this.body,
    required this.features,
  });
}

class OnboardingIntroFeature {
  final IconData icon;
  final String title;
  final String body;

  const OnboardingIntroFeature(this.icon, this.title, this.body);
}

const kOnboardingIntroSlides = [
  OnboardingIntroSlide(
    code: 'SLIDE_01',
    number: '01',
    title: 'Seu personal trainer de IA',
    body:
        'Um coach que te conhece, planeja seu treino e acompanha cada quilometro. Antes, durante e depois da corrida.',
    features: [
      OnboardingIntroFeature(
        Icons.psychology_alt_outlined,
        'Inteligencia adaptativa',
        'O plano evolui com voce a cada corrida',
      ),
      OnboardingIntroFeature(
        Icons.mic_none_outlined,
        'Coach por voz',
        'Orientacao em tempo real, sem tirar o celular do bolso',
      ),
      OnboardingIntroFeature(
        Icons.analytics_outlined,
        'Analise completa',
        'Metricas, zonas cardiacas, benchmark e tendencias',
      ),
    ],
  ),
  OnboardingIntroSlide(
    code: 'SLIDE_02',
    number: '02',
    title: 'Te guia por voz, em tempo real',
    body:
        'Pace, motivacao, dicas. O Coach fala com voce durante a corrida, sem tirar o celular do bolso.',
    features: [
      OnboardingIntroFeature(
        Icons.bolt_outlined,
        'Alertas inteligentes',
        'Avisa quando sair da zona de pace ou BPM alvo',
      ),
      OnboardingIntroFeature(
        Icons.directions_run_outlined,
        'Splits ao vivo',
        'Comentarios a cada km sobre seu desempenho',
      ),
      OnboardingIntroFeature(
        Icons.music_note_outlined,
        'Integra com musica',
        'Volume baixa automaticamente durante orientacoes',
      ),
    ],
  ),
  OnboardingIntroSlide(
    code: 'SLIDE_03',
    number: '03',
    title: 'Evolua e conquiste',
    body:
        'Gamificacao, metas e recompensas que te fazem voltar todo dia. Nao e so correr, e um jogo de evolucao pessoal.',
    features: [
      OnboardingIntroFeature(
        Icons.emoji_events_outlined,
        'Badges e XP',
        'Conquiste marcos, suba de nivel, desbloqueie recompensas',
      ),
      OnboardingIntroFeature(
        Icons.trending_up_outlined,
        'Benchmark',
        'Compare seu desempenho com corredores do seu nivel',
      ),
      OnboardingIntroFeature(
        Icons.calendar_month_outlined,
        'Periodizacao IA',
        'Planejamento mensal/semanal que se adapta ao progresso',
      ),
    ],
  ),
];

class OnboardingStepIntro extends StatelessWidget {
  final OnboardingIntroSlide slide;

  const OnboardingStepIntro({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          Text(
            '// ${slide.code}',
            style: context.runninType.labelMd.copyWith(color: palette.primary),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(slide.title, style: context.runninType.displayLg),
              ),
              const SizedBox(width: 12),
              Text(
                slide.number,
                style: context.runninType.labelMd.copyWith(
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            slide.body,
            style: context.runninType.bodyMd.copyWith(
              color: palette.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          ...slide.features.map(
            (feature) => AppPanel(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(feature.icon, color: palette.primary, size: 19),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: context.runninType.labelMd.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature.body,
                          style: context.runninType.bodySm.copyWith(
                            color: palette.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
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
