import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/data/plan_revision_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/domain/entities/plan_revision.dart';
import 'package:runnin/features/training/domain/week_phase_label.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';
import 'package:runnin/shared/widgets/week_plan_row.dart';

/// Tela da PROPOSTA de revisão semanal (gerada pelo cron de domingo).
/// Mostra a explicação do coach + as próximas semanas propostas (com delta de
/// volume vs o plano atual) e deixa o usuário ACEITAR ou RECUSAR. O plano só
/// muda no aceite.
///
/// Rota: /training/plan-proposal (lê a proposta pendente do plano atual).
class PlanProposalPage extends StatefulWidget {
  const PlanProposalPage({super.key});

  @override
  State<PlanProposalPage> createState() => _PlanProposalPageState();
}

class _PlanProposalPageState extends State<PlanProposalPage> {
  final _planDs = PlanRemoteDatasource();
  final _revisionDs = PlanRevisionRemoteDatasource();

  Plan? _plan;
  PlanRevision? _revision;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _planDs.getCurrentPlan();
      if (!mounted) return;
      if (plan == null || !plan.hasPendingProposal) {
        setState(() {
          _plan = plan;
          _loading = false;
        });
        return;
      }
      final rev = await _revisionDs.getRevision(plan.id, plan.pendingRevisionId!);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _revision = rev;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar a proposta.';
        _loading = false;
      });
    }
  }

  Future<void> _resolve({required bool accept}) async {
    final plan = _plan;
    final rev = _revision;
    if (plan == null || rev == null) return;
    setState(() => _acting = true);
    try {
      if (accept) {
        await _revisionDs.acceptProposal(plan.id, rev.id);
      } else {
        await _revisionDs.rejectProposal(plan.id, rev.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Plano atualizado com a proposta.'
              : 'Proposta recusada — plano mantido.'),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/training');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _acting = false;
        _error = 'Não foi possível ${accept ? 'aceitar' : 'recusar'} agora. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: RunninAppBar(
        title: 'PROPOSTA DO COACH',
        onBack: () => context.pop(),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : _revision == null
              ? _EmptyState(message: _error ?? 'Sem proposta pendente no momento.')
              : _buildContent(palette),
    );
  }

  Widget _buildContent(RunninPalette palette) {
    final rev = _revision!;
    final type = context.runninType;
    final oldKm = _totalKm(rev.oldWeeksSnapshot);
    final newKm = _totalKm(rev.newWeeksSnapshot);
    final delta = newKm - oldKm;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Text(
              'REVISÃO DE DOMINGO',
              style: type.labelCaps.copyWith(color: palette.secondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              'O coach analisou sua semana e propôs ajustar as próximas 2 semanas. '
              'Você decide: aceitar aplica no plano, recusar mantém como está.',
              style: type.bodySm.copyWith(color: palette.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            CoachNarrativeCard(text: rev.coachExplanation, borderColor: palette.secondary),
            const SizedBox(height: 16),
            // Resumo de volume atual × proposto.
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'VOLUME ATUAL',
                    value: oldKm.toStringAsFixed(0),
                    unit: 'km',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'PROPOSTO',
                    value: newKm.toStringAsFixed(0),
                    unit: 'km',
                    valueColor: palette.secondary,
                    delta: delta.abs() < 0.5
                        ? '='
                        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}km',
                    deltaColor: delta >= 0 ? palette.primary : palette.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final week in rev.newWeeksSnapshot) ...[
              _WeekHeader(week: week),
              const SizedBox(height: 8),
              ..._orderedSessions(week).map(
                (s) => WeekPlanRow(
                  dayOfWeek: s.dayOfWeek,
                  session: s,
                  isToday: false,
                  isDone: false,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
        // Barra de ação fixa: ACEITAR / RECUSAR.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: palette.background,
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _acting ? null : () => _resolve(accept: false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.border),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Text('RECUSAR',
                          style: type.labelMd.copyWith(color: palette.muted, letterSpacing: 1.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _acting ? null : () => _resolve(accept: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.background,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: _acting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.background,
                              ),
                            )
                          : Text('ACEITAR PROPOSTA',
                              style: type.labelMd.copyWith(
                                color: palette.background,
                                letterSpacing: 1.0,
                              )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _totalKm(List<PlanWeek> weeks) =>
      weeks.fold(0.0, (s, w) => s + w.sessions.fold(0.0, (a, x) => a + x.distanceKm));

  List<PlanSession> _orderedSessions(PlanWeek week) {
    final list = [...week.sessions]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return list;
  }
}

class _WeekHeader extends StatelessWidget {
  final PlanWeek week;
  const _WeekHeader({required this.week});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final km = week.sessions.fold(0.0, (a, s) => a + s.distanceKm);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: palette.primary.withValues(alpha: 0.12),
          child: Text(
            'SEM ${week.weekNumber}',
            style: type.labelCaps.copyWith(color: palette.primary, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            planWeekLabel(week),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelMd.copyWith(color: palette.text, letterSpacing: 0.5),
          ),
        ),
        Text(
          '${km.toStringAsFixed(0)}km',
          style: type.labelCaps.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, size: 40, color: palette.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: type.bodyMd.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/training'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.primary),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text('VER PLANO',
                  style: type.labelCaps.copyWith(color: palette.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
