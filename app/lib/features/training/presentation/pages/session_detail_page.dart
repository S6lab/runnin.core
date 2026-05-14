import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';

class SessionDetailPage extends StatelessWidget {
  final PlanSession session;
  final PlanWeek week;
  final String planId;

  const SessionDetailPage({
    super.key,
    required this.session,
    required this.week,
    required this.planId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(title: 'SESSÃO'),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SessionHeader(session: session, week: week),
                    const SizedBox(height: 16),
                    _SessionMetrics(session: session),
                    const SizedBox(height: 16),
                    _SessionDescription(session: session),
                    const SizedBox(height: 16),
                    _SessionActions(session: session, week: week, planId: planId),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final PlanSession session;
  final PlanWeek week;

  const _SessionHeader({required this.session, required this.week});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final dayName = _getDayName(session.dayOfWeek);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.muted,
                      letterSpacing: 0.08,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.type,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
            AppTag(
              label: 'SEMANA ${week.weekNumber}',
              color: palette.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _buildSessionGoal(session),
          style: TextStyle(
            color: palette.text.withValues(alpha: 0.8),
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _getDayName(int dayOfWeek) {
    const names = [
      '',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    return names[dayOfWeek];
  }

  String _buildSessionGoal(PlanSession session) {
    final typeLC = session.type.toLowerCase();
    if (typeLC.contains('interval') || typeLC.contains('intervalado')) {
      return 'Blocos fortes com recuperação entre tiros para desenvolver velocidade e VO2.';
    }
    if (typeLC.contains('tempo')) {
      return 'Ritmo sustentado para trabalhar o limiar e aumentar a resistência anaeróbica.';
    }
    if (typeLC.contains('long')) {
      return 'Corrida de volume para construir resistência aeróbica e adaptação.';
    }
    if (typeLC.contains('easy') || typeLC.contains('leve') || typeLC.contains('rodagem')) {
      return 'Corrida leve para recuperação ativa e construir consistência aeróbica.';
    }
    return 'Sessão de treino conforme planejado no seu programa de periodização.';
  }
}

class _SessionMetrics extends StatelessWidget {
  final PlanSession session;

  const _SessionMetrics({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'DISTÂNCIA',
            value: '${session.distanceKm.toStringAsFixed(1)}K',
          ),
        ),
        const SizedBox(width: 8),
        if (session.targetPace != null)
          Expanded(
            child: MetricCard(
              label: 'PACE',
              value: session.targetPace!,
            ),
          ),
      ],
    );
  }
}

class _SessionDescription extends StatelessWidget {
  final PlanSession session;

  const _SessionDescription({required this.session});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTRUTURA DA SESSÃO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 12),
        CoachNarrativeCard(
          text: session.notes.isNotEmpty
              ? session.notes
              : 'Aquecimento → Tiros/ritmo principal → Volta à calma. Respeite os sinais do corpo.',
        ),
        const SizedBox(height: 12),
        AppPanel(
          color: palette.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: palette.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Zonas de Frequência Cardíaca',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Zona 2 (Aeróbica): 60-70% FC máx\nZona 3 (Limiar): 70-85% FC máx',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.text.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionActions extends StatefulWidget {
  final PlanSession session;
  final PlanWeek week;
  final String planId;

  const _SessionActions({required this.session, required this.week, required this.planId});

  @override
  State<_SessionActions> createState() => _SessionActionsState();
}

class _SessionActionsState extends State<_SessionActions> {
  final _datasource = PlanRemoteDatasource();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('INICIAR CORRIDA'),
            onPressed: () => _startRun(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => _markComplete(),
                child: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.runninPalette.primary,
                        ),
                      )
                    : const Text('CONCLUÍDA'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => _skipSession(),
                child: const Text('PULAR'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rescheduleSession(),
                child: const Text('REAGENDAR'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _startRun(BuildContext context) {
    if (widget.session == null || widget.week == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível iniciar a corrida'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    context.push('/prep', extra: {
      'session': widget.session,
      'week': widget.week,
      'planId': widget.planId,
    });
  }

  Future<void> _markComplete() async {
    setState(() => _loading = true);
    try {
      await _datasource.updateSessionStatus(
        planId: widget.planId,
        sessionId: widget.session.id,
        status: 'completed',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão marcada como concluída'),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _skipSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pular sessão?'),
        content: const Text('Você tem certeza que quer pular esta sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await _datasource.updateSessionStatus(
        planId: widget.planId,
        sessionId: widget.session.id,
        status: 'skipped',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão pulada'),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _rescheduleSession() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (date == null) return;

    setState(() => _loading = true);
    try {
      final newDateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _datasource.rescheduleSession(
        planId: widget.planId,
        sessionId: widget.session.id,
        newDate: newDateStr,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão reagendada com sucesso'),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reagendar: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
