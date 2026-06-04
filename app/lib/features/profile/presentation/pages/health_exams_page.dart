import 'package:flutter/material.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/profile/data/exam_remote_datasource.dart';
import 'package:runnin/features/profile/data/exam_uploader.dart';
import 'package:runnin/shared/widgets/figma/figma_exam_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class HealthExamsPage extends StatefulWidget {
  const HealthExamsPage({super.key});

  @override
  State<HealthExamsPage> createState() => _HealthExamsPageState();
}

class _HealthExamsPageState extends State<HealthExamsPage> {
  final _remote = ExamRemoteDatasource();
  final _uploader = ExamUploader();
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
    } catch (e, st) {
      Logger.error('exams.list_failed', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar os exames.';
      });
    }
  }

  /// Abre o flow compartilhado de picker → upload. Recarrega a lista quando
  /// o exame foi persistido; exibe banner inline em falha.
  Future<void> _pickAndUpload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    final outcome = await _uploader.pickAndUpload(context);
    if (!mounted) return;
    if (outcome.isSuccess) {
      await _loadExams();
    } else if (outcome.errorMessage != null) {
      setState(() => _error = outcome.errorMessage);
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'EXAMES',
            showBackButton: true,
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.runninPalette.primary,
              onRefresh: _loadExams,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    _UploadCounter(used: _examsThisMonth(), max: 5),
                    const SizedBox(height: AppSpacing.md),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: context.runninPalette.primary,
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
                    const SizedBox(height: AppSpacing.xxl),
                    _FieldLabel(label: 'EXAMES RECOMENDADOS'),
                    const SizedBox(height: AppSpacing.md),
                    ..._kRecommendedExams.map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RecommendedExamCard(spec: rec),
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

  int _examsThisMonth() {
    if (_exams == null) return 0;
    final now = DateTime.now();
    return _exams!.where((e) {
      final dt = DateTime.tryParse(e.uploadedAt);
      return dt != null && dt.year == now.year && dt.month == now.month;
    }).length;
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
      style: context.runninType.labelCaps.copyWith(
        color: FigmaColors.textMuted,
        fontSize: 10,
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
          width: 1.041,
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
            style: context.runninType.bodyMd.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Anexe seus primeiros exames para que o Coach.AI possa adaptar seu plano.',
            textAlign: TextAlign.center,
            style: context.runninType.labelCaps.copyWith(
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
        color: context.runninPalette.secondary.withValues(alpha: 0.08),
        border: Border.all(
          color: context.runninPalette.secondary.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Text(
        message,
        style: context.runninType.bodyXs.copyWith(
          color: context.runninPalette.secondary,
        ),
      ),
    );
  }
}

class _UploadCounter extends StatelessWidget {
  final int used;
  final int max;
  const _UploadCounter({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final reached = used >= max;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$used/$max uploads este mês',
          style: context.runninType.bodyXs.copyWith(
            fontWeight: FontWeight.w500,
            color: reached ? context.runninPalette.secondary : FigmaColors.textMuted,
          ),
        ),
        if (reached)
          Text(
            'Premium = ilimitado',
            style: context.runninType.labelCaps.copyWith(
              color: context.runninPalette.primary,
            ),
          ),
      ],
    );
  }
}

class _RecommendedExamSpec {
  final String name;
  final String priority; // ALTO | MÉDIO
  const _RecommendedExamSpec({required this.name, required this.priority});
}

const _kRecommendedExams = <_RecommendedExamSpec>[
  _RecommendedExamSpec(name: 'Hemograma completo', priority: 'ALTO'),
  _RecommendedExamSpec(name: 'Ferritina + Ferro sérico', priority: 'ALTO'),
  _RecommendedExamSpec(name: 'Vitamina D (25-OH)', priority: 'ALTO'),
  _RecommendedExamSpec(name: 'TSH + T4 livre', priority: 'MÉDIO'),
  _RecommendedExamSpec(name: 'Glicose + HbA1c', priority: 'MÉDIO'),
];

class _RecommendedExamCard extends StatelessWidget {
  final _RecommendedExamSpec spec;
  const _RecommendedExamCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    final priorityColor =
        spec.priority == 'ALTO' ? context.runninPalette.secondary : FigmaColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              spec.name,
              style: context.runninType.labelMd.copyWith(
                fontWeight: FontWeight.w500,
                color: FigmaColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.15),
              border: Border.all(color: priorityColor, width: 1.0),
            ),
            child: Text(
              spec.priority,
              style: context.runninType.labelCaps.copyWith(
                letterSpacing: 0.8,
                color: priorityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

