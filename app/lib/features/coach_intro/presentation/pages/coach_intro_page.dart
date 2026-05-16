import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// 4-slide Coach.AI briefing per `docs/figma/screens/COACH_INTRO.md`
/// (Figma nodes 1:5770, 1:5818, 1:5870, 1:5922).
///
/// Shown after Plan Loading and before Pre-Run on the first run.
/// Currently routed at `/coach-intro`; persistence ("show only once") is a
/// follow-up tied to ONBOARDING module B12.
class CoachIntroPage extends StatefulWidget {
  const CoachIntroPage({super.key});

  @override
  State<CoachIntroPage> createState() => _CoachIntroPageState();
}

class _CoachIntroPageState extends State<CoachIntroPage> {
  static const _slides = [
    _SlideData(
      label: '// QUEM SOU EU',
      icon: Icons.psychology_outlined,
      heading: 'Eu sou seu Coach.AI',
      paragraph:
          'Não sou um app de cronômetro. Sou um treinador de inteligência artificial que te conhece, se adapta a você e evolui junto. Cada corrida que você faz me torna mais preciso.',
      bullets: [
        'Analiso seu pace, BPM, splits e padrão de recuperação',
        'Comparo com milhares de corredores do seu nível',
        'Aprendo com cada sessão para refinar seu plano',
      ],
    ),
    _SlideData(
      label: '// DURANTE A CORRIDA',
      icon: Icons.mic_none_outlined,
      heading: 'Corro com você',
      paragraph:
          'Vou te guiar por voz em tempo real. Aviso quando acelerar, quando frear, quando respirar fundo. Você só precisa correr — eu cuido dos números.',
      bullets: [
        'Alertas de pace quando sair da zona alvo',
        'Comentários a cada km sobre seu desempenho',
        'Motivação nos últimos quilômetros mais difíceis',
        'Volume da música abaixa automaticamente quando falo',
      ],
    ),
    _SlideData(
      label: '// PRIMEIRA CORRIDA',
      icon: Icons.analytics_outlined,
      heading: 'Essa é a calibração',
      paragraph:
          'Na primeira corrida, vou te avaliar. Corra no seu ritmo natural — sem pressão. Preciso entender seu corpo para criar o plano perfeito.',
      bullets: [
        'Vou medir seu pace natural em diferentes intensidades',
        'Identifico suas zonas cardíacas reais',
        'Calibro a progressão semanal pro seu nível',
        'Após essa corrida, refino todo o plano automaticamente',
      ],
    ),
    _SlideData(
      label: '// SEU PLANO',
      icon: Icons.calendar_today_outlined,
      heading: 'Planejamento inteligente',
      paragraph:
          'Trabalho com ciclos mensais e ajustes semanais. Você pode pedir revisão do plano quando precisar — eu reorganizo tudo mantendo o foco no seu objetivo.',
      bullets: [
        'Periodização mensal com mesociclos de 4 semanas',
        'Ajuste semanal baseado em como você está respondendo',
        'Se não puder correr num dia, reequilibro a semana',
        '1 revisão de plano por semana disponível',
      ],
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) => setState(() => _index = i);

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      // Final CTA "VAMOS CORRER ↗" — into pre-run flow.
      context.go('/prep');
    }
  }

  void _skip() {
    // PULAR — fall back to home; user can start a run from there anytime.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(progress: (_index + 1) / _slides.length),
            _TopNav(slideIndex: _index, onSkip: _skip),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (_, i) => _Slide(data: _slides[i]),
              ),
            ),
            _BottomActions(
              currentIndex: _index,
              total: _slides.length,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _SlideData {
  const _SlideData({
    required this.label,
    required this.icon,
    required this.heading,
    required this.paragraph,
    required this.bullets,
  });

  final String label;
  final IconData icon;
  final String heading;
  final String paragraph;
  final List<String> bullets;
}

// ---------------------------------------------------------------------------
// Top progress bar — 1.986 px, cyan fill proportional to slide index
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress; // 0.0 – 1.0

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.986,
      child: ColoredBox(
        color: FigmaColors.borderDefault, // rgba white 0.08
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: const ColoredBox(color: FigmaColors.brandCyan),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top nav: orange dot + breadcrumb + PULAR
// ---------------------------------------------------------------------------

class _TopNav extends StatelessWidget {
  const _TopNav({required this.slideIndex, required this.onSkip});

  final int slideIndex;
  final VoidCallback onSkip;

  // Per spec: dot opacity oscillates per slide (83% / 62% / 70% / 36%).
  static const _dotOpacities = [0.83, 0.62, 0.70, 0.36];

  @override
  Widget build(BuildContext context) {
    final dotOpacity = _dotOpacities[slideIndex.clamp(0, _dotOpacities.length - 1)];
    return SizedBox(
      height: 49.982,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Opacity(
              opacity: dotOpacity,
              child: const SizedBox(
                width: 9.986,
                height: 9.986,
                child: ColoredBox(color: FigmaColors.brandOrange),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'COACH.AI > BRIEFING INICIAL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                height: 18 / 12,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w400,
                color: FigmaColors.brandOrange,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'PULAR',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  height: 18 / 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textSecondary, // rgba white 0.55
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide content: label + (icon + heading) + paragraph + bullets
// ---------------------------------------------------------------------------

class _Slide extends StatelessWidget {
  const _Slide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              height: 18 / 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w400,
              color: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(data.icon, size: 36, color: FigmaColors.brandCyan),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data.heading,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 26,
                    height: 27.3 / 26,
                    letterSpacing: -0.78,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            data.paragraph,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              height: 25.5 / 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xB3FFFFFF), // rgba white 0.70
            ),
          ),
          const SizedBox(height: 32),
          for (final bullet in data.bullets) ...[
            _BulletCard(text: bullet),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bullet feature card: ▸ marker + text, sutil card surface
// ---------------------------------------------------------------------------

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.fromBorderSide(
          BorderSide(color: FigmaColors.borderDefault, width: 1.735),
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 17.74, vertical: 13.74),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '▸',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              height: 18 / 12,
              fontWeight: FontWeight.w400,
              color: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 19.5 / 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xA6FFFFFF), // rgba white 0.65
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom actions: CTA button + page dots
// ---------------------------------------------------------------------------

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.currentIndex,
    required this.total,
    required this.onNext,
  });

  final int currentIndex;
  final int total;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == total - 1;
    final ctaLabel = isLast ? '[ VAMOS CORRER ]  ↗' : 'CONTINUAR  ↗';

    return SizedBox(
      height: 101.978,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 49.982,
              child: GestureDetector(
                onTap: onNext,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: FigmaColors.brandCyan,
                    borderRadius: FigmaBorderRadius.zero,
                  ),
                  child: Text(
                    ctaLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      height: 18 / 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.bgBase,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PageDots(currentIndex: currentIndex, total: total),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _Dot(state: _stateFor(i)),
        ],
      ],
    );
  }

  _DotState _stateFor(int i) {
    if (i == currentIndex) return _DotState.active;
    if (i < currentIndex) return _DotState.visited;
    return _DotState.inactive;
  }
}

enum _DotState { active, visited, inactive }

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final _DotState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: state == _DotState.active ? 23.998 : 5.986,
      height: 4,
      child: ColoredBox(
        color: switch (state) {
          _DotState.active => FigmaColors.brandCyan,
          _DotState.visited => const Color(0x33FFFFFF), // rgba white 0.20
          _DotState.inactive => const Color(0x0FFFFFFF), // rgba white 0.06
        },
      ),
    );
  }
}
