import 'package:flutter/material.dart';
import 'package:runnin/app/presentation/utils/runnin_palette.g.dart';
import 'package:runnin/features/onboarding/presentation/pages/initial_briefing_page.dart';
import 'package:runnin/features/run/domain/entities/session.dart';

class BriefingPage extends StatefulWidget {
  final Session? session;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  const BriefingPage({
    super.key,
    this.session,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  State<BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends State<BriefingPage>
    with TickerProviderStateMixin {
  late int _currentPage;
  late PageController _pageController;
  late AnimationController _fadeController;

  static const List<BriefingSlide> _briefingSlides =
      BriefingSlides.coachBriefing;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _pageController = PageController(initialPage: 0);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _briefingSlides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skipBriefing() {
    widget.onSkip();
  }

  void _handlePageChange(int page) {
    setState(() {
      _currentPage = page;
    });
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: _briefingSlides.length,
                onPageChanged: _handlePageChange,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeController,
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
                                _briefingSlides[index].icon,
                                size: 48,
                                color: palette.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _briefingSlides[index].title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _briefingSlides[index].body,
                            style: context.runninType.bodyMd.copyWith(
                              color: palette.muted,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
