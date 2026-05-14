import 'package:flutter/material.dart';
import 'package:go_router/go_router_delegate.dart';
import 'package:runnin/app/presentation/utils/runnin_palette.g.dart';
import 'package:runnin/features/run/domain/entities/session.dart';

class BriefingPage extends StatefulWidget {
  final Session session;
  final Function(String type) onSkip;
  final Function(String type, String? briefingText) onComplete;

  const BriefingPage({
    super.key,
    required this.session,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  State<BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends State<BriefingPage>
    with TickerProviderStateMixin {
  late int _currentPage;
  late AnimationController _controller;

  static const List<String> _briefingSlides = [
    'Bem-vindo à sua corrida!',
    'Vamos analisar seu objetivo.',
    'Verificando seu histórico.',
    'Pronto para largar?',
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _briefingSlides.length - 1) {
      setState(() {
        _currentPage++;
      });
    } else {
      widget.onComplete(widget.session.type, null);
    }
  }

  void _skipBriefing() {
    widget.onSkip(widget.session.type);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'COACH BRIEFING',
                    style: context.runninType.labelCaps,
                  ),
                  TextButton(
                    onPressed: _skipBriefing,
                    child: Text('PULAR', style: context.runninType.labelSmall),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    key: ValueKey(_currentPage),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                _currentPage == 0
                                    ? Icons.person_add_outlined
                                    : _currentPage == 1
                                        ? Icons.target_rounded
                                        : _currentPage == 2
                                            ? Icons.history
                                            : Icons.play_arrow,
                                size: 48,
                                color: palette.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _briefingSlides[_currentPage],
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentPage + 1} de ${_briefingSlides.length}',
                    style: context.runninType.bodySm.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _currentPage == _briefingSlides.length - 1
                          ? 'INICIAR'
                          : 'AVANÇAR',
                      style: context.runninType.labelCaps.copyWith(
                        color: palette.background,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
