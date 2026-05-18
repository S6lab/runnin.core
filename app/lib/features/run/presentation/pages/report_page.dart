import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

class ReportPage extends StatefulWidget {
  final String runId;
  const ReportPage({super.key, required this.runId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportSections {
  final String runAnalysis;
  final String planEvolution;
  final String nextSessions;
  final String recommendations;
  const _ReportSections({
    required this.runAnalysis,
    required this.planEvolution,
    required this.nextSessions,
    required this.recommendations,
  });
}

class _ReportPageState extends State<ReportPage> {
  final _remote = RunRemoteDatasource();
  Run? _run;
  String? _summary;
  _ReportSections? _sections;
  // Status segue o backend: pending | summary_ready | enriched | ready (legacy).
  // Render por estado: pending=skeleton, summary_ready/ready=card único,
  // enriched=4 cards expansíveis.
  String _reportStatus = 'pending';
  bool _loadingRun = true;
  String? _reportError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadRun();
    _pollReport();
  }

  Future<void> _loadRun() async {
    try {
      final run = await _remote.getRun(widget.runId);
      if (mounted) setState(() { _run = run; _loadingRun = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  Future<void> _pollReport() async {
    int attempts = 0;
    // 50 × 3s = 150s. Two-phase: summary_ready chega em ~30s, enriched
    // (fase B com adaptPlan + 4 seções) leva +30s a +60s. Polling para
    // ao atingir 'enriched' ou esgotar tentativas.
    const maxAttempts = 50;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (attempts++ > maxAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            if (_reportStatus == 'pending') {
              _reportError =
                  'Relatório demorando mais que o normal. Volta em alguns minutos no histórico.';
            }
            // Se já temos summary_ready, mantém o que está sem flag de erro —
            // user vê o que tem e enriched pode aparecer no histórico depois.
          });
        }
        return;
      }
      try {
        final res = await apiClient.get('/coach/report/${widget.runId}');
        final data = res.data as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'pending';
        final summary = data['summary'] as String?;
        final sectionsRaw = data['sections'];

        _ReportSections? parsedSections;
        if (sectionsRaw is Map<String, dynamic>) {
          parsedSections = _ReportSections(
            runAnalysis: (sectionsRaw['runAnalysis'] as String?)?.trim() ?? '',
            planEvolution: (sectionsRaw['planEvolution'] as String?)?.trim() ?? '',
            nextSessions: (sectionsRaw['nextSessions'] as String?)?.trim() ?? '',
            recommendations: (sectionsRaw['recommendations'] as String?)?.trim() ?? '',
          );
        }

        if (mounted) {
          setState(() {
            _reportStatus = status;
            if (summary != null && summary.isNotEmpty) _summary = summary;
            if (parsedSections != null) _sections = parsedSections;
            _reportError = null;
          });
        }

        // Para o polling em estados terminais: enriched é o destino final,
        // ready é legacy (reports antigos) — não tem fase B pra esperar.
        if (status == 'enriched' || status == 'ready') {
          timer.cancel();
        }
      } catch (e) {
        // Antes: catch (_) {} silencioso. Agora guarda último erro pra
        // mostrar caso polling termine sem sucesso.
        if (mounted) _reportError = 'Erro buscando relatório: $e';
      }
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('RELATÓRIO'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/home')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORRIDA CONCLUÍDA',
              style: context.runninType.labelCaps.copyWith(color: palette.primary),
            ),
            const SizedBox(height: 24),

            if (_loadingRun)
              Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
            else if (_run != null)
              _StatsRow(run: _run!),

            const SizedBox(height: 24),

            if (_run?.xpEarned != null && _run!.xpEarned! > 0)
              _XpBadge(xp: _run!.xpEarned!),

            if (_run?.xpEarned != null && _run!.xpEarned! > 0)
              const SizedBox(height: 24),

            // Coach report — render adaptativo por status:
            //   pending → skeleton com mensagem "Analisando..."
            //   summary_ready/ready → card único com resumo (fase A do two-phase)
            //   enriched → 4 ExpansionTile (Análise / Evolução / Próximas / Recomendações)
            _CoachReportBlock(
              status: _reportStatus,
              summary: _summary,
              sections: _sections,
              error: _reportError,
              palette: palette,
            ),

            const SizedBox(height: 24),
            if (_run != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/share', extra: {'runId': widget.runId}),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.primary),
                    foregroundColor: palette.primary,
                  ),
                  child: const Text('COMPARTILHAR'),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('VOLTAR PARA HOME'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Run run;
  const _StatsRow({required this.run});

  String _fmt(int seconds) {
    final m = seconds ~/ 60; final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _StatCell(
            label: 'DISTÂNCIA',
            value: (run.distanceM / 1000).toStringAsFixed(2),
            unit: 'km',
          ),
          _Divider(),
          _StatCell(
            label: 'TEMPO',
            value: _fmt(run.durationS),
            unit: '',
          ),
          _Divider(),
          _StatCell(
            label: 'PACE MÉD.',
            value: run.avgPace ?? '--:--',
            unit: '/km',
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value, unit;
  const _StatCell({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: type.labelCaps),
          const SizedBox(height: 6),
          RichText(text: TextSpan(
            text: value,
            style: type.dataMd,
            children: [if (unit.isNotEmpty) TextSpan(
              text: ' $unit',
              style: type.bodySm,
            )],
          )),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 40, color: context.runninPalette.border,
  );
}

class _CoachReportBlock extends StatelessWidget {
  final String status;
  final String? summary;
  final _ReportSections? sections;
  final String? error;
  final dynamic palette;

  const _CoachReportBlock({
    required this.status,
    required this.summary,
    required this.sections,
    required this.error,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    final hasEnriched = status == 'enriched' && sections != null;

    if (hasEnriched) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COACH.AI', style: type.labelCaps.copyWith(color: palette.secondary)),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'ANÁLISE DA CORRIDA',
            body: sections!.runAnalysis,
            initiallyExpanded: true,
            palette: palette,
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'EVOLUÇÃO NO PLANO',
            body: sections!.planEvolution,
            palette: palette,
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'PRÓXIMAS SESSÕES',
            body: sections!.nextSessions,
            palette: palette,
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'RECOMENDAÇÕES',
            body: sections!.recommendations,
            palette: palette,
          ),
        ],
      );
    }

    // Fallback: pending, summary_ready ou ready (legacy) → card único.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.secondary, width: 3)),
        color: palette.secondary.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COACH.AI', style: type.labelCaps.copyWith(color: palette.secondary)),
          const SizedBox(height: 8),
          if (status == 'pending' && summary == null)
            Row(children: [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
              ),
              const SizedBox(width: 10),
              Text(
                'Analisando sua corrida... (até 2 minutos)',
                style: type.bodySm,
              ),
            ])
          else if (summary != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary!, style: type.bodyMd.copyWith(height: 1.6)),
                // Hint sutil enquanto fase B roda em background.
                if (status == 'summary_ready') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.2, color: palette.muted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Análise completa em poucos segundos...',
                      style: type.labelCaps.copyWith(color: palette.muted),
                    ),
                  ]),
                ],
              ],
            )
          else
            Text(
              error ?? 'Relatório não disponível.',
              style: type.bodyMd.copyWith(height: 1.6),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String body;
  final bool initiallyExpanded;
  final dynamic palette;

  const _ReportCard({
    required this.title,
    required this.body,
    required this.palette,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.secondary, width: 3)),
          color: palette.secondary.withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(title, style: type.labelCaps.copyWith(color: palette.secondary)),
          iconColor: palette.secondary,
          collapsedIconColor: palette.secondary,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(body, style: type.bodyMd.copyWith(height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final int xp;
  const _XpBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.1),
        border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: palette.primary),
          const SizedBox(width: 6),
          Text(
            '+$xp XP',
            style: context.runninType.labelMd.copyWith(
              color: palette.primary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
