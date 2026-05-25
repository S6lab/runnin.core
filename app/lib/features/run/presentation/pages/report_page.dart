import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';

class ReportPage extends StatefulWidget {
  final String runId;
  const ReportPage({super.key, required this.runId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _remote = RunRemoteDatasource();
  Run? _run;
  String? _summary;
  // Status do backend: pending | summary_ready | enriched | ready (legacy).
  // Two-phase: summary curto em ~30s → enriched (texto longo) em até ~150s.
  // Texto enriched SOBRESCREVE o summary curto quando chega.
  String _reportStatus = 'pending';
  bool _loadingRun = true;
  String? _reportError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadRun();
    // Coach AI report é feature premium. Freemium nem dispara polling
    // pra não bater no backend nem mostrar card de "analisando...".
    if (subscriptionController.isPro) {
      _pollReport();
    }
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
    // (fase B com adaptPlan + texto completo) leva +30s a +60s. Polling
    // para ao atingir 'enriched' ou esgotar tentativas.
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

        if (mounted) {
          setState(() {
            _reportStatus = status;
            if (summary != null && summary.isNotEmpty) _summary = summary;
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

            // Coach report — texto contínuo. Pending mostra skeleton.
            // summary_ready/ready mostra summary curto + hint "análise
            // completa em segundos". Enriched mostra summary expandido
            // (texto markdown com `## ` headings renderizado contínuo).
            // Premium-only: freemium não vê nem o card "Analisando...".
            if (subscriptionController.isPro) ...[
              _CoachReportBlock(
                status: _reportStatus,
                summary: _summary,
                error: _reportError,
                palette: palette,
              ),
              const SizedBox(height: 24),
            ],
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

/// Bloco do coach na ReportPage. Renderiza texto markdown contínuo —
/// sem cards expansíveis, sem parsing JSON. Quando summary é o texto
/// curto (fase A), mostra como parágrafo simples. Quando é o texto
/// enriched (fase B, com `## ` headings), divide em parágrafos e
/// destaca os headings.
class _CoachReportBlock extends StatelessWidget {
  final String status;
  final String? summary;
  final String? error;
  final dynamic palette;

  const _CoachReportBlock({
    required this.status,
    required this.summary,
    required this.error,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.secondary, width: 3)),
        color: palette.secondary.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COACH.AI', style: type.labelCaps.copyWith(color: palette.secondary)),
          const SizedBox(height: 12),
          if (status == 'pending' && (summary == null || summary!.isEmpty))
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
          else if (summary != null && summary!.isNotEmpty)
            _MarkdownReport(text: summary!, palette: palette, isEnriching: status == 'summary_ready')
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

/// Renderiza texto markdown leve do coach: parágrafos comuns + headings
/// `## TÍTULO`. Substitui o `_MarkdownText` de plan_detail (que tem
/// suporte a bullets/bold) — aqui só precisamos de heading + parágrafo.
/// Quando isEnriching=true, mostra hint sutil no fim sinalizando que
/// a análise completa está chegando.
class _MarkdownReport extends StatelessWidget {
  final String text;
  final dynamic palette;
  final bool isEnriching;

  const _MarkdownReport({
    required this.text,
    required this.palette,
    required this.isEnriching,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    final widgets = <Widget>[];
    final lines = text.split('\n');
    final paragraph = StringBuffer();

    void flushParagraph() {
      final p = paragraph.toString().trim();
      if (p.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            p,
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: null,
            style: type.bodyMd.copyWith(color: palette.text, height: 1.6),
          ),
        ));
      }
      paragraph.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('## ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            line.substring(3).trim(),
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: null,
            style: type.labelCaps.copyWith(
              color: palette.secondary,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      } else if (line.isEmpty) {
        flushParagraph();
      } else {
        if (paragraph.isNotEmpty) paragraph.write(' ');
        paragraph.write(line);
      }
    }
    flushParagraph();

    if (isEnriching) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
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
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
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
