import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';

class InitialBriefingSlide {
  final String title;
  final String body;
  final List<String> featureIcons;
  final List<String> features;

  const InitialBriefingSlide({
    required this.title,
    required this.body,
    required this.featureIcons,
    required this.features,
  });
}

class InitialBriefingPage extends StatefulWidget {
  final int currentIndex;
  final List<InitialBriefingSlide> slides;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  const InitialBriefingPage({
    super.key,
    this.currentIndex = 0,
    required this.slides,
    this.onNext,
    this.onSkip,
  });

  @override
  State<InitialBriefingPage> createState() => _InitialBriefingPageState();
}

class _InitialBriefingPageState extends State<InitialBriefingPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant InitialBriefingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _currentIndex = widget.currentIndex;
    }
  }

  void _nextSlide() {
    if (_currentIndex < widget.slides.length - 1) {
      setState(() => _currentIndex++);
      widget.onNext?.call();
    } else {
      _completeBriefing();
    }
  }

  void _skipBriefing() {
    widget.onSkip?.call();
    _completeBriefing();
  }

  void _previousSlide() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _completeBriefing() async {
    try {
      await UserRemoteDatasource().patchMe(onboarded: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar progresso: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    if (_currentIndex >= widget.slides.length) {
      _completeBriefing();
      return const SizedBox.shrink();
    }

    final slide = widget.slides[_currentIndex];
    final isLastSlide = _currentIndex == widget.slides.length - 1;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(child: _buildContent(slide)),
              const SizedBox(height: 18),
              _buildNav(palette, type),
              const SizedBox(height: 12),
              _StepDots(
                total: widget.slides.length,
                current: _currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (_currentIndex > 0)
          OutlinedButton(
            onPressed: _previousSlide,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(86, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('< VOLTAR'),
          )
        else
          const SizedBox(width: 86, height: 38),
        const Spacer(),
        Text('RUNIN', style: context.runninType.labelMd),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: context.runninPalette.primary,
          child: Text(
            '.AI',
            style: context.runninType.labelMd.copyWith(
              color: context.runninPalette.background,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_currentIndex < widget.slides.length - 1)
          TextButton(
            onPressed: _skipBriefing,
            child: const Text('PULAR'),
          )
        else
          const SizedBox(width: 66),
      ],
    );
  }

  Widget _buildContent(InitialBriefingSlide slide) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          Text(
            'Briefing ${_currentIndex + 1}/${widget.slides.length}',
            style: context.runninType.labelMd.copyWith(
              color: context.runninPalette.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(slide.title, style: context.runninType.displayLg),
          const SizedBox(height: 20),
          Text(
            slide.body,
            style: context.runninType.bodyMd.copyWith(
              color: context.runninPalette.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          ...slide.features.asMap().entries.map((entry) => _buildFeature(
            entry.key + 1,
            slide.featureIcons[entry.key],
            slide.features[entry.key],
          )),
        ],
      ),
    );
  }

  Widget _buildFeature(int index, String iconData, String text) {
    final palette = context.runninPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconFromString(iconData),
              color: palette.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: context.runninType.bodyMd.copyWith(
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNav(dynamic palette, dynamic type) {
    final isLastSlide = _currentIndex == widget.slides.length - 1;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _nextSlide,
        child: Text(
          isLastSlide ? 'INICIAR CORRIDA' : 'CONTINUAR',
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int total;
  final int current;

  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final active = index == current.clamp(0, total - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 14 : 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: active ? palette.primary : palette.border,
        );
      }),
    );
  }
}

IconData _iconFromString(String iconString) {
  switch (iconString.toLowerCase()) {
    case 'psychology':
      return Icons.psychology_alt_outlined;
    case 'mic':
      return Icons.mic_none_outlined;
    case 'analytics':
      return Icons.analytics_outlined;
    case 'bolt':
      return Icons.bolt_outlined;
    case 'directions_run':
      return Icons.directions_run_outlined;
    case 'music_note':
      return Icons.music_note_outlined;
    case 'emoji_events':
      return Icons.emoji_events_outlined;
    case 'trending_up':
      return Icons.trending_up_outlined;
    case 'calendar_month':
      return Icons.calendar_month_outlined;
    default:
      return Icons.circle_outline;
  }
}
