import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
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
  final _runDs = RunRemoteDatasource();
  Plan? _plan;
  Run? _runOfThisDay;
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
      // Tenta achar a corrida concluída neste dia (busca últimos 90 dias).
      if (plan != null) {
        final dayDate = _dateOf(plan);
        final runs = await _runDs.listRuns(limit: 200);
        _runOfThisDay = runs.cast<Run?>().firstWhere(
              (r) =>
                  r != null &&
                  r.status == 'completed' &&
                  _sameDay(DateTime.tryParse(r.createdAt), dayDate),
              orElse: () => null,
            );
      }
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

  bool _sameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
                        style: TextStyle(color: palette.error)),
                  ),
                )
              : _plan == null
                  ? Center(
                      child: Text(
                        'Nenhum plano ativo.',
                        style: TextStyle(color: palette.muted),
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
    final run = _runOfThisDay;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _DateHeader(date: dateLabel, weekNumber: widget.weekNumber),
        const SizedBox(height: 16),
        if (session != null) ...[
          _PlannedSessionCard(session: session),
          if (isPast && run != null) ...[
            const SizedBox(height: 14),
            _PlanVsRealCard(session: session, run: run),
          ],
          if (isPast && run == null) ...[
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
      padding: const EdgeInsets.all(14),
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
            style: GoogleFonts.jetBrainsMono(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            'SEMANA $weekNumber',
            style: GoogleFonts.jetBrainsMono(
              color: palette.muted,
              fontSize: 11,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: palette.primary,
                child: Text(
                  'SESSÃO PLANEJADA',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.background,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session.type.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: palette.text,
              fontSize: 22,
              fontWeight: FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: palette.muted.withValues(alpha: 0.3),
                child: Text(
                  'DIA DE DESCANSO',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.text,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tip.focus != null && tip.focus!.isNotEmpty)
            Text(
              tip.focus!.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w500,
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
            style: GoogleFonts.jetBrainsMono(
              color: palette.muted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sem sessão planejada — aproveita pra descansar, hidratar (~peso × 0.035L) e alimentação leve. O coach ajusta o próximo plano se quiser mudar essa rotina.',
            style: TextStyle(color: palette.text, fontSize: 12.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _PlanVsRealCard extends StatelessWidget {
  final PlanSession session;
  final Run run;
  const _PlanVsRealCard({required this.session, required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final realKm = run.distanceM / 1000.0;
    final realDurationMin = run.durationS / 60.0;
    final plannedKm = session.distanceKm;
    final plannedMin = session.durationMin;
    final kmRatio = plannedKm > 0 ? realKm / plannedKm : 0;
    final hitDistance = kmRatio >= 0.9 && kmRatio <= 1.15;
    final hitTime = plannedMin != null
        ? (realDurationMin / plannedMin) >= 0.85 &&
            (realDurationMin / plannedMin) <= 1.2
        : null;
    final hitAll = hitDistance && (hitTime ?? true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (hitAll ? palette.primary : palette.warning)
            .withValues(alpha: 0.06),
        border: Border.all(
          color: (hitAll ? palette.primary : palette.warning)
              .withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hitAll ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: hitAll ? palette.primary : palette.muted,
              ),
              const SizedBox(width: 8),
              Text(
                hitAll ? 'METAS ATINGIDAS' : 'PLANEJADO vs REALIZADO',
                style: GoogleFonts.jetBrainsMono(
                  color: hitAll ? palette.primary : palette.text,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ComparisonRow(
            label: 'DISTÂNCIA',
            planned: '${plannedKm.toStringAsFixed(1)} km',
            real: '${realKm.toStringAsFixed(2)} km',
            hit: hitDistance,
          ),
          if (plannedMin != null)
            _ComparisonRow(
              label: 'TEMPO',
              planned: '~${plannedMin.round()} min',
              real: '${realDurationMin.toStringAsFixed(0)} min',
              hit: hitTime ?? false,
            ),
          if (run.avgPace != null && session.targetPace != null)
            _ComparisonRow(
              label: 'PACE',
              planned: '${session.targetPace}/km',
              real: '${run.avgPace}',
              hit: true, // sem regra rigorosa de pace ainda — só compara
            ),
          if (run.avgBpm != null)
            _ComparisonRow(
              label: 'BPM MÉDIO',
              planned: '—',
              real: '${run.avgBpm} bpm',
              hit: true,
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
      padding: const EdgeInsets.all(14),
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
              style: TextStyle(
                color: palette.text,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String planned;
  final String real;
  final bool hit;
  const _ComparisonRow({
    required this.label,
    required this.planned,
    required this.real,
    required this.hit,
  });
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              planned,
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              real,
              style: TextStyle(
                color: palette.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            hit ? Icons.check : Icons.remove,
            size: 14,
            color: hit ? palette.primary : palette.muted,
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
                          style: GoogleFonts.jetBrainsMono(
                            color: palette.muted,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.value,
                      style: GoogleFonts.jetBrainsMono(
                        color: palette.text,
                        fontSize: 14,
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
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
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
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(color: palette.text, fontSize: 12.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}
