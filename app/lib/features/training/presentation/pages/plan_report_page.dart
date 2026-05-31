import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Painel titulado pra agrupar blocos do relatório. AppPanel não aceita
/// title; criamos um wrapper simples local pra não inflar o shared widget.
class _TitledPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _TitledPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.runninType.labelMd.copyWith(
              color: palette.muted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Relatório final do plano concluído (status='completed' detectado lazy
/// no server quando mesocycleEndDate passou). Mostra:
///  - objetivo, nível, datas (início, prazo inicial, conclusão real)
///  - chip ✓ no prazo / ★ adiantado / ✗ atrasado
///  - planejado: total km + sessões somando do plan.weeks (sem endpoint
///    dedicado de "realizado vs planejado" por intervalo — quando esse
///    endpoint existir, plugamos aqui)
///  - lista de revisões (checkpoints aceitos) — plan.revisions[]
///  - CTA "GERAR NOVO PLANO"
class PlanReportPage extends StatefulWidget {
  final String planId;
  const PlanReportPage({super.key, required this.planId});

  @override
  State<PlanReportPage> createState() => _PlanReportPageState();
}

class _PlanReportPageState extends State<PlanReportPage> {
  final _ds = PlanRemoteDatasource();
  Plan? _plan;
  bool _loading = true;
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
      final plan = await _ds.getPlanById(widget.planId);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não consegui carregar o relatório do plano.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final plan = _plan;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const RunninAppBar(
        title: 'RELATÓRIO DO PLANO',
        fallbackRoute: '/training',
      ),
      bottomNavigationBar: plan == null
          ? null
          : _Footer(onNewPlan: () => context.push('/training/criar-plano')),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: context.runninType.bodyMd.copyWith(color: palette.error),
                    ),
                  ),
                )
              : plan == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        _HeaderCard(plan: plan),
                        const SizedBox(height: 14),
                        _DeadlineCard(plan: plan),
                        const SizedBox(height: 14),
                        _NumbersCard(plan: plan),
                        if (plan.revisions.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _RevisionsCard(plan: plan),
                        ],
                        const SizedBox(height: 14),
                        _TitledPanel(
                          title: 'PRÓXIMO PASSO',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seu plano terminou. Você pode gerar um novo plano (objetivo igual ou diferente) ou usar o Flow pra continuar evoluindo sem meta específica.',
                                style: context.runninType.bodySm.copyWith(
                                  color: palette.text,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  // Sem locale custom: initializeDateFormatting('pt_BR') não é chamado no
  // boot, e DateFormat com 'pt_BR' lança LocaleDataException → tela branca.
  // 'dd/MM/yyyy' não precisa de locale (só dígitos).
  return DateFormat('dd/MM/yyyy').format(d);
}

class _HeaderCard extends StatelessWidget {
  final Plan plan;
  const _HeaderCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return _TitledPanel(
      title: 'OBJETIVO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.goal.toUpperCase(),
            style: context.runninType.dataMd.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nível: ${plan.level} · ${plan.weeksCount} semanas',
            style: context.runninType.bodySm.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final Plan plan;
  const _DeadlineCard({required this.plan});

  /// Compara prazo inicial e conclusão real. Retorna (icon, label, color).
  (IconData, String, Color) _verdict(BuildContext context) {
    final palette = context.runninPalette;
    final initial = plan.initialDeadlineAt;
    final completed = plan.completedAt;
    if (initial == null || completed == null) {
      return (Icons.flag_outlined, 'Sem prazo registrado', palette.muted);
    }
    final i = DateTime.tryParse(initial);
    final c = DateTime.tryParse(completed);
    if (i == null || c == null) {
      return (Icons.flag_outlined, 'Sem prazo registrado', palette.muted);
    }
    final diff = c.difference(i).inDays;
    if (diff < -1) {
      return (Icons.star, 'Adiantado em ${diff.abs()} dias', palette.primary);
    }
    if (diff > 1) {
      return (Icons.flag_outlined, 'Atrasado em $diff dias', palette.error);
    }
    return (Icons.check_circle_outline, 'No prazo', palette.primary);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final (icon, label, color) = _verdict(context);
    return _TitledPanel(
      title: 'PRAZO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Início', _fmtDate(plan.startDate)),
          const SizedBox(height: 4),
          _row(context, 'Prazo inicial', _fmtDate(plan.initialDeadlineAt)),
          const SizedBox(height: 4),
          _row(context, 'Conclusão real', _fmtDate(plan.completedAt)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.runninType.bodyMd.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Comparação entre o prazo INICIAL (gravado quando o plano foi criado) e a conclusão real. Os checkpoints semanais podem ter ajustado o caminho — o prazo inicial é só o baseline.',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final palette = context.runninPalette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.runninType.bodySm.copyWith(color: palette.muted)),
        Text(
          value,
          style: context.runninType.bodySm.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NumbersCard extends StatelessWidget {
  final Plan plan;
  const _NumbersCard({required this.plan});

  double get _plannedKm {
    double total = 0;
    for (final w in plan.weeks) {
      for (final s in w.sessions) {
        total += s.distanceKm;
      }
    }
    return total;
  }

  int get _plannedSessions {
    int total = 0;
    for (final w in plan.weeks) {
      total += w.sessions.length;
    }
    return total;
  }

  int get _executedSessions {
    int done = 0;
    for (final w in plan.weeks) {
      for (final s in w.sessions) {
        if (s.executedRunId != null && s.executedRunId!.isNotEmpty) done++;
      }
    }
    return done;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final planned = _plannedSessions;
    final executed = _executedSessions;
    final adherence = planned == 0 ? 0.0 : (executed / planned) * 100;
    return _TitledPanel(
      title: 'NÚMEROS DO PLANO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Volume planejado', '${_plannedKm.toStringAsFixed(0)} km'),
          const SizedBox(height: 4),
          _row(context, 'Sessões planejadas', '$planned'),
          const SizedBox(height: 4),
          _row(context, 'Sessões executadas', '$executed'),
          const SizedBox(height: 4),
          _row(context, 'Adesão', '${adherence.toStringAsFixed(0)}%'),
          const SizedBox(height: 10),
          Text(
            'Volume realizado em km e pace médio do período vão aparecer aqui na próxima versão (depende de filtro por intervalo no /stats).',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final palette = context.runninPalette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.runninType.bodySm.copyWith(color: palette.muted)),
        Text(
          value,
          style: context.runninType.bodySm.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RevisionsCard extends StatelessWidget {
  final Plan plan;
  const _RevisionsCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final revisions = plan.revisions;
    return _TitledPanel(
      title: 'AJUSTES (${revisions.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cada ajuste corresponde a um checkpoint semanal onde o coach reescreveu as próximas semanas a partir do seu desempenho.',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in revisions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semana ${r.weekNumber} · ${_fmtDate(r.revisedAt)}',
                      style: context.runninType.labelMd.copyWith(
                        color: palette.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.summary,
                      style: context.runninType.bodySm.copyWith(
                        color: palette.text,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onNewPlan;
  const _Footer({required this.onNewPlan});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.border, width: 1.041)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onNewPlan,
            child: const Text('GERAR NOVO PLANO /'),
          ),
        ),
      ),
    );
  }
}
