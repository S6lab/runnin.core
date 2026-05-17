import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// 3 slides pré-login que vendem o app antes de pedir compromisso (psicologia:
/// mostra valor antes da fricção). Após o último slide vai pra /login.
/// `intro_seen` flag em Hive evita repetir nas próximas aberturas.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  static const _settingsBoxName = 'runnin_settings';
  static const _introSeenKey = 'intro_seen';

  final _controller = PageController();
  int _index = 0;

  static const _slides = <_IntroSlide>[
    _IntroSlide(
      eyebrow: '// COACH.AI',
      title: 'Um coach que te conhece.',
      body:
          'Plano de corrida adaptado ao seu nível, objetivo, rotina e dados de saúde. '
          'Não é template genérico — é seu plano, seu pace, seu progresso.',
      icon: Icons.psychology_outlined,
    ),
    _IntroSlide(
      eyebrow: '// CORRIDA AO VIVO',
      title: 'Guia por voz na sua corrida.',
      body:
          'O coach acompanha cada km. Avisa quando segurar o pace, quando soltar, '
          'quando descansar. Como ter um treinador no ouvido.',
      icon: Icons.headphones_outlined,
    ),
    _IntroSlide(
      eyebrow: '// EVOLUÇÃO',
      title: 'Histórico que conta sua jornada.',
      body:
          'Todas as corridas, conquistas e relatórios em um lugar. '
          'Compartilhe seus melhores momentos com a comunidade.',
      icon: Icons.trending_up_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    final box = Hive.isBoxOpen(_settingsBoxName)
        ? Hive.box<dynamic>(_settingsBoxName)
        : await Hive.openBox<dynamic>(_settingsBoxName);
    await box.put(_introSeenKey, true);
  }

  Future<void> _advance() async {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      await _markSeen();
      if (!mounted) return;
      context.go('/login');
    }
  }

  Future<void> _skip() async {
    await _markSeen();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('RUNNIN', style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 1.4,
                      )),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        color: FigmaColors.brandCyan,
                        child: Text('.AI', style: GoogleFonts.jetBrainsMono(
                          color: FigmaColors.bgBase, fontSize: 9, fontWeight: FontWeight.w500,
                        )),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'PULAR',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _IntroSlideView(slide: _slides[i]),
              ),
            ),
            // Indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 4,
                    color: active ? FigmaColors.brandCyan : Colors.white.withValues(alpha: 0.18),
                  );
                }),
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _advance,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: FigmaColors.brandCyan,
                    alignment: Alignment.center,
                    child: Text(
                      _index == _slides.length - 1 ? 'COMEÇAR ↗' : 'PRÓXIMO ↗',
                      style: GoogleFonts.jetBrainsMono(
                        color: FigmaColors.bgBase,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide {
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  const _IntroSlide({required this.eyebrow, required this.title, required this.body, required this.icon});
}

class _IntroSlideView extends StatelessWidget {
  final _IntroSlide slide;
  const _IntroSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FigmaColors.brandCyan.withValues(alpha: 0.1),
              border: Border.all(color: FigmaColors.brandCyan, width: 1.041),
            ),
            child: Icon(slide.icon, color: FigmaColors.brandCyan, size: 32),
          ),
          const SizedBox(height: 32),
          Text(
            slide.eyebrow,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: FigmaColors.brandCyan,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            slide.body,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
