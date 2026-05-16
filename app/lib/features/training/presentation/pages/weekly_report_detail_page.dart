import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/features/training/data/weekly_report_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_adherence_progress.dart';
import 'package:runnin/shared/widgets/figma/figma_highlight_bullet.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';

class WeeklyReportDetailPage extends StatefulWidget {
  final String weekStart;
  final WeeklyReport? report;

  const WeeklyReportDetailPage({
    super.key,
    required this.weekStart,
    this.report,
  });

  @override
  State<WeeklyReportDetailPage> createState() => _WeeklyReportDetailPageState();
}

class _WeeklyReportDetailPageState extends State<WeeklyReportDetailPage> {
  final _ds = WeeklyReportRemoteDatasource();
  WeeklyReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    
    if (widget.report != null) {
      _report = widget.report;
    } else {
      try {
        _report = await _ds.getWeeklyReportByWeekStart(widget.weekStart);
      } catch (e) {
        print('Error loading weekly report: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.runninPalette.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_report == null) {
      return Scaffold(
        backgroundColor: context.runninPalette.background,
        body: SafeArea(
          child: Center(
            child: Text('Relatório não encontrado'),
          ),
        ),
      );
    }

    final weeklyReport = _report!;
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(title: 'RELATÓRIO SEMANAL'),
              const SizedBox(height: 20),
              _buildAdherenceCard(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildHighlightsSection(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildCoachAnalysisSection(palette, weeklyReport),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    return FigmaAdherenceProgress(
      percent: report.adherencePercent,
      sessionsDone: report.sessionsDone,
      sessionsPlanned: report.sessionsPlanned,
    );
  }

  Widget _buildHighlightsSection(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final highlights = report.highlights?.trim();
    if (highlights == null || highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final highlightLines = highlights.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (highlightLines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESTAQUES',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 12),
        ...highlightLines.map((line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('+')) {
            return FigmaHighlightBullet(
              type: HighlightType.positive,
              text: trimmed.substring(1).trim(),
            );
          } else if (trimmed.startsWith('!')) {
            return FigmaHighlightBullet(
              type: HighlightType.alert,
              text: trimmed.substring(1).trim(),
            );
          } else {
            return FigmaHighlightBullet(
              type: HighlightType.positive,
              text: trimmed,
            );
          }
        }),
      ],
    );
  }

  Widget _buildCoachAnalysisSection(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final analysis = report.coachAnalysis?.trim();
    if (analysis == null || analysis.isEmpty) {
      return const SizedBox.shrink();
    }

    return FigmaCoachAIBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaCoachAIBreadcrumb(action: 'ANÁLISE DO COACH'),
          const SizedBox(height: 12),
          Text(
            analysis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }
}
