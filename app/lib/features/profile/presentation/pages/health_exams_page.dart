import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/profile/data/exam_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_exam_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthExamsPage extends StatefulWidget {
  const HealthExamsPage({super.key});

  @override
  State<HealthExamsPage> createState() => _HealthExamsPageState();
}

class _HealthExamsPageState extends State<HealthExamsPage> {
  final _remote = ExamRemoteDatasource();
  List<Exam>? _exams;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await _remote.listExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar os exames.';
      });
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final urlResult = await _remote.getUploadUrl(
        examName: picked.name,
        fileName: picked.name,
        fileSize: picked.size,
      );
      await _remote.finalize(urlResult.examId);
      await _loadExams();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha no upload. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Saúde / Exames',
            showBackButton: true,
          ),
          Expanded(
            child: RefreshIndicator(
              color: FigmaColors.brandCyan,
              onRefresh: _loadExams,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    FigmaExamUploadCTA(
                      onTap: _uploading ? () {} : _pickAndUpload,
                      label: _uploading
                          ? 'Enviando...'
                          : '+ Adicionar exame',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    _FieldLabel(label: 'EXAMES'),
                    const SizedBox(height: AppSpacing.md),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: FigmaColors.brandCyan,
                            strokeWidth: 1.5,
                          ),
                        ),
                      )
                    else if (_exams == null || _exams!.isEmpty)
                      const _EmptyState()
                    else
                      ..._exams!.map(
                        (exam) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: FigmaExamCard(
                            examName: exam.examName,
                            fileName: exam.fileName,
                            sizeLabel: _formatBytes(exam.fileSize),
                            dateLabel: _formatDate(exam.uploadedAt),
                            coachAnalysis:
                                exam.coachAnalysis ?? 'Analisando...',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }
}

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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nenhum exame registrado',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Anexe seus primeiros exames para que o Coach.AI possa adaptar seu plano.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              height: 1.5,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: FigmaColors.brandOrange.withValues(alpha: 0.08),
        border: Border.all(
          color: FigmaColors.brandOrange.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: FigmaColors.brandOrange,
        ),
      ),
    );
  }
}
