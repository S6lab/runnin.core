import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/data/plan_revision_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan_revision.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';

class AdjustmentsHistoryPage extends StatefulWidget {
  final String? planId;
  const AdjustmentsHistoryPage({super.key, this.planId});

  @override
  State<AdjustmentsHistoryPage> createState() => _AdjustmentsHistoryPageState();
}

class _AdjustmentsHistoryPageState extends State<AdjustmentsHistoryPage> {
  final _ds = PlanRevisionRemoteDatasource();
  List<PlanRevision> _revisions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdjustmentsHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId) _load();
  }

  Future<void> _load() async {
    if (widget.planId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final revisions = await _ds.listRevisions(widget.planId!);
      if (!mounted) return;
      setState(() {
        _revisions = revisions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar histórico.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: palette.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuotaCard(
          palette: palette,
          usedThisWeek: _revisions.where((r) => _isThisWeek(r.createdAt)).length,
        ),
        const SizedBox(height: 12),
        _CoachEducationalCard(palette: palette),
        const SizedBox(height: 12),
        if (widget.planId != null)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/training/revise?planId=${widget.planId}'),
              child: const Text('SOLICITAR ALTERAÇÃO ↗'),
            ),
          ),
        const SizedBox(height: 20),
        if (_revisions.isEmpty)
          _EmptyRevisions(palette: palette)
        else ...[
          Text(
            'SOLICITAÇÕES ANTERIORES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.08,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 12),
          ..._revisions.map((r) => _RevisionCard(revision: r, palette: palette)),
          const SizedBox(height: 20),
          _CalendarVisualization(revisions: _revisions, palette: palette),
        ],
      ],
    );
  }

  bool _isThisWeek(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(weekStart.subtract(const Duration(days: 1)));
  }
}

class _QuotaCard extends StatelessWidget {
  final RunninPalette palette;
  final int usedThisWeek;

  const _QuotaCard({required this.palette, required this.usedThisWeek});

  @override
  Widget build(BuildContext context) {
    final remaining = (1 - usedThisWeek).clamp(0, 1);

    return AppPanel(
      borderColor: palette.secondary.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTag(
                label: 'REVISÃO USADA ESTA SEMANA',
                color: palette.secondary,
              ),
              const Spacer(),
              Text(
                '$usedThisWeek/1',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: palette.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            child: LinearProgressIndicator(
              value: usedThisWeek.toDouble(),
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation(palette.secondary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '$remaining alteração disponível esta semana'
                : 'Próxima disponível na próxima semana',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CoachEducationalCard extends StatelessWidget {
  final RunninPalette palette;

  const _CoachEducationalCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    return FigmaCoachAIBlock(
      variant: CoachAIBlockVariant.appGeneral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaCoachAIBreadcrumb(action: 'COMO FUNCIONAM AS REVISÕES'),
          const SizedBox(height: 8),
          Text(
            'Você pode solicitar 1 alteração por semana. O Coach.AI analisa seus dados '
            'clínicos, exames e histórico de treino para recalcular as semanas futuras '
            'do seu plano sem comprometer a periodização.',
            style: TextStyle(color: palette.text, height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyRevisions extends StatelessWidget {
  final RunninPalette palette;

  const _EmptyRevisions({required this.palette});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: palette.surfaceAlt,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 40, color: palette.border),
          const SizedBox(height: 12),
          Text(
            'Nenhuma solicitação ainda',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quando você solicitar alterações no plano, o histórico aparecerá aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  final PlanRevision revision;
  final RunninPalette palette;

  const _RevisionCard({required this.revision, required this.palette});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(revision.createdAt);
    final dateLabel = date != null
        ? DateFormat('dd/MM · HH:mm').format(date.toLocal())
        : '--';

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: revision.isApplied
          ? palette.primary.withValues(alpha: 0.4)
          : palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Semana ${revision.weekIndex + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
              if (revision.isApplied)
                AppTag(label: 'APLICADO', color: palette.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _revisionTypeLabel(revision.type) +
                (revision.subOption != null ? ' · ${revision.subOption}' : ''),
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            revision.coachExplanation,
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(dateLabel, style: TextStyle(color: palette.border, fontSize: 11)),
        ],
      ),
    );
  }

  String _revisionTypeLabel(String type) {
    const labels = {
      'more_load': 'Mais carga',
      'less_load': 'Menos carga',
      'more_days': 'Mais dias',
      'less_days': 'Menos dias',
      'more_tempo': 'Mais tempo runs',
      'more_resistance': 'Mais resistência',
      'more_intervals': 'Mais intervalados',
      'change_days': 'Mudar dias',
      'pain_or_discomfort': 'Dor/Desconforto',
      'other': 'Outro',
    };
    return labels[type] ?? type;
  }
}

class _CalendarVisualization extends StatelessWidget {
  final List<PlanRevision> revisions;
  final RunninPalette palette;

  const _CalendarVisualization({required this.revisions, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CALENDÁRIO DE REVISÕES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.08,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(4, (i) {
            final weekNum = i + 1;
            final hasRevision = revisions.any((r) => r.weekIndex == i);
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: hasRevision
                      ? palette.primary.withValues(alpha: 0.1)
                      : palette.surface,
                  border: Border.all(
                    color: hasRevision
                        ? palette.primary.withValues(alpha: 0.5)
                        : palette.border,
                    width: 1.041,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'S$weekNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hasRevision ? palette.primary : palette.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      hasRevision ? Icons.check : Icons.remove,
                      size: 14,
                      color: hasRevision ? palette.primary : palette.border,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
