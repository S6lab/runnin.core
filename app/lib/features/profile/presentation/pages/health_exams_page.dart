import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_exam_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthExamsPage extends StatelessWidget {
  const HealthExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const _TopNav(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _ExamUploadCTA(),
                  const SizedBox(height: 24),
                  _FieldLabel(label: 'EXAMES'),
                  const SizedBox(height: 8),
                  if (_mockExams.isEmpty)
                    _EmptyState()
                  else
                    ..._mockExams.map((exam) => ExamCard(
                          examName: exam.examName,
                          fileName: exam.fileName,
                          sizeLabel: exam.sizeLabel,
                          dateLabel: exam.dateLabel,
                          coachAnalysis: exam.coachAnalysis,
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Navigation ──────────────────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    return FigmaTopNav(
      breadcrumb: 'Perfil / Saúde / Exames',
      showBackButton: false,
    );
  }
}

// ── Exam Upload CTA ─────────────────────────────────────────────────────────

class _ExamUploadCTA extends StatelessWidget {
  const _ExamUploadCTA();

  @override
  Widget build(BuildContext context) {
    return FigmaExamUploadCTA(
      onTap: () => _showComingSoon(context),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Upload de exames — em breve.'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ── Field Label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        color: FigmaColors.textMuted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: FigmaDimensions.borderUniversal,
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: 1.735,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: FigmaColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum exame registrado',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anexe seus primeiros exames aqui',
            style: TextStyle(
              fontSize: 10,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mock Data ───────────────────────────────────────────────────────────────

class _MockExam {
  final String examName;
  final String fileName;
  final String sizeLabel;
  final String dateLabel;
  final String? coachAnalysis;

  const _MockExam({
    required this.examName,
    required this.fileName,
    required this.sizeLabel,
    required this.dateLabel,
    this.coachAnalysis,
  });
}

const List<_MockExam> _mockExams = [];

class ExamCard extends StatelessWidget {
  final String examName;
  final String fileName;
  final String sizeLabel;
  final String dateLabel;
  final String? coachAnalysis;

  const ExamCard({
    required this.examName,
    required this.fileName,
    required this.sizeLabel,
    required this.dateLabel,
    this.coachAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return FigmaExamCard(
      examName: examName,
      fileName: fileName,
      sizeLabel: sizeLabel,
      dateLabel: dateLabel,
      coachAnalysis: coachAnalysis,
    );
  }
}
