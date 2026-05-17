import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/features/training/data/weekly_report_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_adherence_progress.dart';
import 'package:runnin/shared/widgets/figma/figma_highlight_bullet.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

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
        debugPrint('Error loading weekly report: $e');
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
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Treino / Relatório semanal',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportInfoSection(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildAdherenceCard(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildStatsTiles(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildFreeTrainingCard(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildCoachAnalysisSection(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildHighlightsSection(palette, weeklyReport),
              const SizedBox(height: 20),
              _buildAdaptationSuggestionSection(palette, weeklyReport),
              const SizedBox(height: 20),
                  _buildCTASection(palette, weeklyReport),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportInfoSection(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final dateRange = report.dateRange ?? 'Data não disponível';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '// RELATÓRIO SEMANAL',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Semana ${_formatWeekStart(report.weekStart)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dateRange,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: palette.muted,
          ),
        ),
      ],
    );
  }

  String _formatWeekStart(String weekStart) {
    try {
      final date = DateTime.parse(weekStart);
      return DateFormat('dd/MM').format(date);
    } catch (_) {
      return weekStart;
    }
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

  Widget _buildStatsTiles(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final avgPace = report.averagePace != null
        ? _formatPace(report.averagePace!)
        : '--:--';
    final km = report.totalKm.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatTile(
          label: 'KM TOTAL',
          value: km,
          color: palette.primary,
        ),
        const SizedBox(height: 12),
        _StatTile(
          label: 'PACE MÉD',
          value: avgPace,
          color: palette.secondary,
        ),
        const SizedBox(height: 12),
        _StatTile(
          label: 'SESSÕES',
          value: '${report.sessionsDone} de ${report.sessionsPlanned}',
          color: palette.primary,
        ),
      ],
    );
  }

  String _formatPace(double pace) {
    final minutes = pace.toInt();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildFreeTrainingCard(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final hasAdaptation = report.adaptationSuggestion != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCardOrange,
        border: Border.all(color: FigmaColors.borderOrange, width: 1.041),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FigmaCoachAIBreadcrumb(action: 'TREINOS LIVRES INTEGRADOS'),
              if (hasAdaptation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: palette.secondary,
                  child: Text(
                    'ADAPTADO',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                      color: FigmaColors.bgBase,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${report.totalFreeSessions} treinos livres • ${report.freeKm.toStringAsFixed(1)}K extras',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: palette.text,
            ),
          ),
        ],
      ),
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
            fontWeight: FontWeight.w500,
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

  Widget _buildAdaptationSuggestionSection(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    final suggestion = report.adaptationSuggestion?.trim();
    if (suggestion == null || suggestion.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCardOrange,
        border: Border.all(color: FigmaColors.borderOrange, width: 1.041),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaCoachAIBreadcrumb(action: 'ADAPTAÇÃO SUGERIDA'),
          const SizedBox(height: 12),
          Text(
            suggestion,
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

  Widget _buildCTASection(
    RunninPalette palette,
    WeeklyReport report,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          height: 48,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'CONVERSAR COM COACH ↗',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.background,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: palette.border, width: 1.041),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              'MANTER PLANO ATUAL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '1 revisão disponível por semana',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: palette.muted,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.041),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: palette.muted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
