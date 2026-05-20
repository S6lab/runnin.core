import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Página detalhada de um DIA específico do plano.
/// Rota: /training/day/:weekNumber/:dayOfWeek
///
/// Mostra para o dia:
/// - SE tem sessão planejada: tipo, distância, pace alvo, tempo alvo,
///   hidratação, alimentação pré/pós, orientações do coach (notes).
/// - SE é dia de descanso: hidratação, alimentação anti-inflamatória,
///   focus (rest day tip).
/// - SE o dia já passou e há corrida concluída: cards "PLANEJADO vs
///   REAL" + check de metas atingidas.
class DayDetailPage extends StatefulWidget {
  final int weekNumber;
  final int dayOfWeek;
  const DayDetailPage({
    super.key,
    required this.weekNumber,
    required this.dayOfWeek,
  });

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  final _planDs = PlanRemoteDatasource();
  Plan? _plan;
  bool _loading = true;
  String? _error;

  static const _dayNames = ['', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

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
      _plan = plan;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  /// Calcula a data real desse (week, day) baseado em plan.effectiveStartDate.
  DateTime _dateOf(Plan plan) {
    final start = plan.effectiveStartDate;
    final startDow = start.weekday;
    final daysFromStart = (widget.weekNumber - 1) * 7 + (widget.dayOfWeek - startDow);
    return start.add(Duration(days: daysFromStart));
  }

  PlanWeek? get _week =>
      _plan?.weeks.cast<PlanWeek?>().firstWhere(
            (w) => w?.weekNumber == widget.weekNumber,
            orElse: () => null,
          );

  PlanSession? get _session => _week?.sessions
      .cast<PlanSession?>()
      .firstWhere((s) => s?.dayOfWeek == widget.dayOfWeek, orElse: () => null);

  PlanRestDayTip? get _restTip => _week?.restDayTips
      .cast<PlanRestDayTip?>()
      .firstWhere((t) => t?.dayOfWeek == widget.dayOfWeek, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final dow = widget.dayOfWeek.clamp(1, 7);
    final dayLabel = _dayNames[dow];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: RunninAppBar(
        title: 'DIA · $dayLabel'.toUpperCase(),
        fallbackRoute: '/training',
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: palette.primary,
                strokeWidth: 2,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: context.runninType.bodyMd
                            .copyWith(color: palette.error)),
                  ),
                )
              : _plan == null
                  ? Center(
                      child: Text(
                        'Nenhum plano ativo.',
                        style: context.runninType.bodySm,
                      ),
                    )
                  : _buildContent(palette),
    );
  }

  Widget _buildContent(dynamic palette) {
    final session = _session;
    final restTip = _restTip;
    final date = _dateOf(_plan!);
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(hours: 4)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _DateHeader(date: dateLabel, weekNumber: widget.weekNumber),
        const SizedBox(height: 16),
        if (session != null) ...[
          _PlannedSessionCard(session: session),
          // "Concluído" vem da corrida real vinculada (executedRunId),
          // não de comparação data×plano.
          if (session.isExecuted) ...[
            const SizedBox(height: 14),
            _CompletedSessionCard(),
          ] else if (isPast) ...[
            const SizedBox(height: 14),
            _MissedSessionCard(),
          ],
        ] else if (restTip != null) ...[
          _RestDayCard(tip: restTip),
        ] else ...[
          _GenericRestCard(),
        ],
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  final int weekNumber;
  const _DateHeader({required this.date, required this.weekNumber});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 18, color: palette.primary),
          const SizedBox(width: 10),
          Text(
            date,
            style: context.runninType.dataSm.copyWith(
              color: palette.text,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            'SEMANA $weekNumber',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 11,
              color: palette.muted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedSessionCard extends StatelessWidget {
  final PlanSession session;
  const _PlannedSessionCard({required this.session});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                color: palette.primary,
                child: Text(
                  'SESSÃO PLANEJADA',
                  style: context.runninType.labelCaps.copyWith(
                    color: palette.background,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session.type.toUpperCase(),
            style: context.runninType.dataXs.copyWith(
              color: palette.text,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _DetailGrid(items: [
            _Detail(
              icon: Icons.straighten,
              label: 'DISTÂNCIA',
              value: '${session.distanceKm.toStringAsFixed(1)} km',
            ),
            if (session.targetPace != null)
              _Detail(
                icon: Icons.speed,
                label: 'PACE ALVO',
                value: '${session.targetPace}/km',
              ),
            if (session.durationMin != null)
              _Detail(
                icon: Icons.timer_outlined,
                label: 'TEMPO ALVO',
                value: '~${session.durationMin!.round()}min',
              ),
            if (session.hydrationLiters != null)
              _Detail(
                icon: Icons.water_drop_outlined,
                label: 'HIDRATAÇÃO',
                value: '${session.hydrationLiters!.toStringAsFixed(1)}L no dia',
              ),
          ]),
          if ((session.nutritionPre ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            _NutritionBlock(
              icon: Icons.restaurant_outlined,
              label: 'PRÉ-TREINO',
              text: session.nutritionPre!,
            ),
          ],
          if ((session.nutritionPost ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _NutritionBlock(
              icon: Icons.fastfood_outlined,
              label: 'PÓS-TREINO',
              text: session.nutritionPost!,
            ),
          ],
          if (session.notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            _OrientationBlock(text: session.notes),
          ],
          if (session.executionSegments.isNotEmpty) ...[
            const SizedBox(height: 20),
            _ExecutionTimeline(segments: session.executionSegments),
          ],
        ],
      ),
    );
  }
}

/// Timeline km-a-km com instruções literais do coach pra executar a
/// sessão. Cada segment vira um card numerado mostrando faixa de km,
/// fase, pace alvo, tempo e a fala do coach.
class _ExecutionTimeline extends StatelessWidget {
  final List<PlanSegment> segments;
  const _ExecutionTimeline({required this.segments});

  static const _phaseLabels = {
    'warmup': 'AQUECIMENTO',
    'main': 'PRINCIPAL',
    'interval': 'TIRO',
    'recovery': 'RECUPERAÇÃO',
    'cooldown': 'DESAQUECIMENTO',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered, size: 16, color: palette.primary),
            const SizedBox(width: 8),
            Text(
              'ROTEIRO DA SESSÃO · ${segments.length} fases',
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                color: palette.primary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'O que o coach vai te dizer em cada km. Use o fone — ele acompanha em tempo real.',
          style: context.runninType.bodyXs,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < segments.length; i++)
          _SegmentCard(
            index: i + 1,
            segment: segments[i],
            phaseLabel: _phaseLabels[segments[i].phase.toLowerCase()] ??
                segments[i].phase.toUpperCase(),
            isLast: i == segments.length - 1,
          ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final int index;
  final PlanSegment segment;
  final String phaseLabel;
  final bool isLast;
  const _SegmentCard({
    required this.index,
    required this.segment,
    required this.phaseLabel,
    required this.isLast,
  });

  Color _phaseColor(BuildContext context) {
    final palette = context.runninPalette;
    switch (segment.phase.toLowerCase()) {
      case 'warmup':
        return palette.warning;
      case 'main':
        return palette.primary;
      case 'interval':
        return palette.error;
      case 'recovery':
        return palette.muted;
      case 'cooldown':
        return palette.secondary;
      default:
        return palette.primary;
    }
  }

  String _kmRange() {
    String fmt(double v) =>
        v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return 'KM ${fmt(segment.kmStart)} → ${fmt(segment.kmEnd)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final accent = _phaseColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coluna esquerda: índice + linha conectora
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent, width: 1.0),
                  ),
                  child: Text(
                    '$index',
                    style: context.runninType.labelMd.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: palette.border,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Coluna direita: card com info do segment
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border.all(color: palette.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: accent.withValues(alpha: 0.15),
                          child: Text(
                            phaseLabel,
                            style: context.runninType.labelCaps.copyWith(
                              fontSize: 9,
                              color: accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _kmRange(),
                          style: context.runninType.labelCaps.copyWith(
                            color: palette.muted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    if (segment.targetPace != null || segment.durationMin != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (segment.targetPace != null) ...[
                            Icon(Icons.speed, size: 11, color: palette.muted),
                            const SizedBox(width: 4),
                            Text(
                              '${segment.targetPace}/km',
                              style: context.runninType.bodyXs.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (segment.durationMin != null) ...[
                            Icon(Icons.timer_outlined,
                                size: 11, color: palette.muted),
                            const SizedBox(width: 4),
                            Text(
                              '~${segment.durationMin!.round()}min',
                              style: context.runninType.bodyXs.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      segment.instruction,
                      style: context.runninType.bodySm.copyWith(
                        color: palette.text,
                        height: 1.5,
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
}

class _RestDayCard extends StatelessWidget {
  final PlanRestDayTip tip;
  const _RestDayCard({required this.tip});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                color: palette.muted.withValues(alpha: 0.3),
                child: Text(
                  'DIA DE DESCANSO',
                  style: context.runninType.labelCaps.copyWith(
                    color: palette.text,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tip.focus != null && tip.focus!.isNotEmpty)
            Text(
              tip.focus!.toUpperCase(),
              style: context.runninType.displaySm.copyWith(
                color: palette.text,
                fontSize: 18,
              ),
            ),
          const SizedBox(height: 14),
          _DetailGrid(items: [
            if (tip.hydrationLiters != null)
              _Detail(
                icon: Icons.water_drop_outlined,
                label: 'HIDRATAÇÃO',
                value: '${tip.hydrationLiters!.toStringAsFixed(1)}L no dia',
              ),
          ]),
          if ((tip.nutrition ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            _NutritionBlock(
              icon: Icons.eco_outlined,
              label: 'ALIMENTAÇÃO RECUPERAÇÃO',
              text: tip.nutrition!,
            ),
          ],
        ],
      ),
    );
  }
}

class _GenericRestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIA DE DESCANSO',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 11,
              color: palette.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sem sessão planejada — aproveita pra descansar, hidratar (~peso × 0.035L) e alimentação leve. O coach ajusta o próximo plano se quiser mudar essa rotina.',
            style: context.runninType.bodyMd.copyWith(
              color: palette.text,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.08),
        border: Border.all(color: palette.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: palette.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sessão não registrada nesta data. O coach vai realocar carga nos próximos dias.',
              style: context.runninType.bodySm.copyWith(
                color: palette.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmação de sessão concluída — mostrada quando a sessão tem
/// `executedRunId` (corrida real vinculada). Substitui o antigo
/// "PLANEJADO vs REALIZADO".
class _CompletedSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.06),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sessão concluída. Bom trabalho — essa sessão entra no fechamento da semana.',
              style: context.runninType.bodySm.copyWith(
                color: palette.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail {
  final IconData icon;
  final String label;
  final String value;
  const _Detail({required this.icon, required this.label, required this.value});
}

class _DetailGrid extends StatelessWidget {
  final List<_Detail> items;
  const _DetailGrid({required this.items});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((d) => Container(
                width: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border.all(color: palette.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(d.icon, size: 14, color: palette.muted),
                        const SizedBox(width: 6),
                        Text(
                          d.label,
                          style: context.runninType.labelCaps.copyWith(
                            color: palette.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.value,
                      style: context.runninType.bodyMd.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _NutritionBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  const _NutritionBlock({
    required this.icon,
    required this.label,
    required this.text,
  });
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.runninType.labelCaps.copyWith(
                  color: palette.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: context.runninType.bodyMd.copyWith(
              color: palette.text,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrientationBlock extends StatelessWidget {
  final String text;
  const _OrientationBlock({required this.text});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.05),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 14, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'ORIENTAÇÕES DO COACH',
                style: context.runninType.labelCaps.copyWith(
                  color: palette.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: context.runninType.bodyMd.copyWith(
              color: palette.text,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
