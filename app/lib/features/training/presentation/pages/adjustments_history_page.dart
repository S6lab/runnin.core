import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/data/plan_revision_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
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
            Text(_error!, style: context.runninType.bodyMd.copyWith(color: palette.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      );
    }

    // Mais recente primeiro.
    final sorted = [..._revisions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoachEducationalCard(palette: palette),
        const SizedBox(height: 20),
        if (sorted.isEmpty)
          _EmptyRevisions(palette: palette)
        else ...[
          Text(
            'AJUSTES DO COACH',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.08,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((r) => _RevisionCard(revision: r, palette: palette)),
        ],
      ],
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
          const FigmaCoachAIBreadcrumb(action: 'COMO FUNCIONAM OS AJUSTES'),
          const SizedBox(height: 8),
          Text(
            'Todo domingo à noite o Coach revisa sua semana — corridas, ritmos e o '
            'que você relatou em cada treino. Quando faz sentido, ele ajusta as '
            'próximas 2 semanas. Quando o plano está rolando bem, ele só confirma e '
            'segue.',
            style: context.runninType.bodyMd.copyWith(color: palette.text, height: 1.5, fontSize: 13),
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
            'Sem ajustes ainda',
            style: context.runninType.dataSm.copyWith(
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'O primeiro ajuste acontece no domingo após sua primeira semana. '
            'Suas corridas e relatos ficam visíveis pro coach até lá.',
            textAlign: TextAlign.center,
            style: context.runninType.bodyMd.copyWith(color: palette.muted, height: 1.5),
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
    final noChanges = revision.newWeeksSnapshot.isEmpty;
    final date = DateTime.tryParse(revision.createdAt);
    final dateLabel = date != null
        ? DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal())
        : '--';

    final title = noChanges
        ? 'Plano completo da semana'
        : 'Semana ${revision.weekIndex + 1} revisada';
    final badgeLabel = noChanges ? 'SEM AJUSTES' : 'AJUSTADO';
    final badgeColor = noChanges ? palette.muted : palette.primary;
    final borderColor = noChanges
        ? palette.border
        : palette.primary.withValues(alpha: 0.4);

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.runninType.dataSm.copyWith(
                    fontSize: 16,
                    color: palette.text,
                  ),
                ),
              ),
              AppTag(label: badgeLabel, color: badgeColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Semana ${revision.weekIndex + 1} · $dateLabel',
            style: context.runninType.bodyXs.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          Text(
            revision.coachExplanation,
            style: context.runninType.bodyMd.copyWith(color: palette.text, height: 1.5),
          ),
          if (!noChanges) ...[
            const SizedBox(height: 16),
            _ChangesDiff(
              oldWeeks: revision.oldWeeksSnapshot,
              newWeeks: revision.newWeeksSnapshot,
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangesDiff extends StatelessWidget {
  final List<PlanWeek> oldWeeks;
  final List<PlanWeek> newWeeks;
  final RunninPalette palette;

  const _ChangesDiff({
    required this.oldWeeks,
    required this.newWeeks,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    // Diff só das 2 primeiras semanas seguintes (~15 dias) — alinhado com o
    // two-tier do checkpoint (N+1 e N+2 ganham detalhe). Pares casados por
    // weekNumber pra robustez se o LLM devolver em outra ordem.
    final byNum = {for (final w in oldWeeks) w.weekNumber: w};
    final pairs = newWeeks
        .take(2)
        .map((newW) => _DiffPair(old: byNum[newW.weekNumber], fresh: newW))
        .where((p) => p.old != null)
        .toList();

    if (pairs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MUDANÇAS NOS PRÓXIMOS 15 DIAS',
          style: context.runninType.labelCaps.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.08,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 10),
        ...pairs.map((p) => _WeekDiffRow(pair: p, palette: palette)),
      ],
    );
  }
}

class _DiffPair {
  final PlanWeek? old;
  final PlanWeek fresh;
  _DiffPair({required this.old, required this.fresh});
}

class _WeekDiffRow extends StatelessWidget {
  final _DiffPair pair;
  final RunninPalette palette;

  const _WeekDiffRow({required this.pair, required this.palette});

  @override
  Widget build(BuildContext context) {
    final old = pair.old!;
    final fresh = pair.fresh;
    final oldKm = _totalKm(old);
    final newKm = _totalKm(fresh);
    final deltaKm = newKm - oldKm;
    final oldSessions = old.sessions.length;
    final newSessions = fresh.sessions.length;
    final deltaSessions = newSessions - oldSessions;

    final hasVolumeChange = deltaKm.abs() >= 0.1;
    final hasSessionChange = deltaSessions != 0;
    final unchanged = !hasVolumeChange && !hasSessionChange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'S${fresh.weekNumber}',
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unchanged
                  ? '${newKm.toStringAsFixed(1)}km · $newSessions sessões'
                  : '${oldKm.toStringAsFixed(1)}→${newKm.toStringAsFixed(1)}km · $oldSessions→$newSessions sessões',
              style: context.runninType.bodySm.copyWith(color: palette.muted),
            ),
          ),
          if (!unchanged) ...[
            const SizedBox(width: 8),
            _DeltaChip(
              deltaKm: deltaKm,
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }

  double _totalKm(PlanWeek w) =>
      w.sessions.fold<double>(0, (sum, s) => sum + s.distanceKm);
}

class _DeltaChip extends StatelessWidget {
  final double deltaKm;
  final RunninPalette palette;

  const _DeltaChip({required this.deltaKm, required this.palette});

  @override
  Widget build(BuildContext context) {
    final sign = deltaKm > 0 ? '+' : '';
    final color = deltaKm > 0 ? palette.primary : palette.secondary;
    final magnitude = math.max(deltaKm.abs(), 0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$sign${magnitude.toStringAsFixed(1)}km',
        style: context.runninType.labelCaps.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
