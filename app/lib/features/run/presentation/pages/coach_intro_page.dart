import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';

class CoachIntroPage extends StatefulWidget {
  const CoachIntroPage({super.key});

  @override
  State<CoachIntroPage> createState() => _CoachIntroPageState();
}

class _CoachIntroPageState extends State<CoachIntroPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _CoachIntroSlide(
      icon: Icons.record_voice_over_rounded,
      title: 'Coach de Voz ao Vivo',
      body:
          'Durante a corrida, o coach analisa seu pace, distância e progresso em tempo real para guiar você com comandos de voz e mensagens diretas.',
    ),
    _CoachIntroSlide(
      icon: Icons.route_rounded,
      title: 'Análise de Percurso',
      body:
          'O GPS detalhado mapeia cada quilômetro. O coach identifica padrões, sugere ajustes de ritmo e avisa quando acelerar ou recuperar.',
    ),
    _CoachIntroSlide(
      icon: Icons.insights_rounded,
      title: 'Relatório Inteligente',
      body:
          'Após a corrida, um relatório completo com análise do coach, zonas de esforço, evolução de pace e recomendações para o próximo treino.',
    ),
    _CoachIntroSlide(
      icon: Icons.share_rounded,
      title: 'Compartilhe sua Performance',
      body:
          'Gere um card personalizado com os dados da corrida para compartilhar com amigos, treinador ou nas redes sociais.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.pushReplacement('/prep');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _dotIndicator(palette, type),
                  const Spacer(),
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: () => context.pushReplacement('/prep'),
                      child: Text(
                        'PULAR',
                        style: type.labelCaps.copyWith(color: palette.muted),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 44,
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          style: type.displayMd.copyWith(
                            fontSize: 28,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          slide.body,
                          style: type.bodyMd.copyWith(
                            color: palette.muted,
                            height: 1.6,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _currentPage < _slides.length - 1
                        ? 'PRÓXIMO'
                        : 'COMEÇAR',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotIndicator(RunninPalette palette, RunninTypography type) {
    return Row(
      children: List.generate(_slides.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 8),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? palette.primary : palette.border,
          ),
        );
      }),
    );
  }
}

class _CoachIntroSlide {
  final IconData icon;
  final String title;
  final String body;

  const _CoachIntroSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}
