import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';

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

  // Feedback subjetivo do user — substitui o fluxo de checkpoint solto.
  // Server agrega o feedback das runs da semana no cron de domingo.
  final Set<CheckpointInputKind> _selectedKinds = {};
  final Map<CheckpointInputKind, String> _kindNotes = {};
  bool _savingFeedback = false;
  bool _feedbackSaved = false;
  String? _feedbackError;

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
      if (mounted) {
        setState(() {
          _run = run;
          _loadingRun = false;
          // Se o user já submeteu feedback antes (re-entrou na página),
          // rehidrata seleção pra mostrar o estado atual em vez de vazio.
          if (run.userFeedback.isNotEmpty) {
            _selectedKinds
              ..clear()
              ..addAll(run.userFeedback.map((i) => i.kind));
            _kindNotes.clear();
            for (final i in run.userFeedback) {
              if (i.note != null) _kindNotes[i.kind] = i.note!;
            }
            _feedbackSaved = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  bool _feedbackValid() {
    for (final k in _selectedKinds) {
      if (k.requiresNote) {
        final note = _kindNotes[k]?.trim();
        if (note == null || note.isEmpty) return false;
      }
    }
    return true;
  }

  Future<void> _submitFeedback() async {
    if (_selectedKinds.isEmpty) {
      setState(() => _feedbackError = 'Escolha pelo menos uma opção pra registrar como foi.');
      return;
    }
    if (!_feedbackValid()) {
      setState(() => _feedbackError = 'Detalhe os itens marcados como "dor" ou "outro".');
      return;
    }
    setState(() {
      _savingFeedback = true;
      _feedbackError = null;
    });
    final inputs = _selectedKinds.map((k) {
      final note = _kindNotes[k]?.trim();
      return CheckpointInput(
        kind: k,
        note: note != null && note.isNotEmpty ? note : null,
      );
    }).toList();
    try {
      final updated = await _remote.submitFeedback(widget.runId, inputs);
      if (!mounted) return;
      setState(() {
        _run = updated;
        _feedbackSaved = true;
        _savingFeedback = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final raw = e.response?.data is Map ? e.response!.data as Map : null;
      final err = raw?['error'] is Map ? raw!['error'] as Map : null;
      setState(() {
        _feedbackError = (err?['message'] as String?) ?? 'Erro ao salvar feedback.';
        _savingFeedback = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackError = 'Erro inesperado salvando feedback.';
        _savingFeedback = false;
      });
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

            // Feedback do user sobre ESTA corrida. Substitui o checkpoint
            // solto: o cron de domingo agrega o feedback das runs da
            // semana pra propor revisão do plano. Aparece pra todo mundo
            // (freemium + premium) — sem feedback, cron não tem leitura
            // subjetiva pra correlacionar com os números.
            if (_run != null) ...[
              _FeedbackBlock(
                palette: palette,
                selected: _selectedKinds,
                notes: _kindNotes,
                saved: _feedbackSaved,
                saving: _savingFeedback,
                error: _feedbackError,
                onToggle: (k) => setState(() {
                  if (_selectedKinds.contains(k)) {
                    _selectedKinds.remove(k);
                    _kindNotes.remove(k);
                  } else {
                    _selectedKinds.add(k);
                  }
                  _feedbackError = null;
                }),
                onNoteChanged: (k, v) => _kindNotes[k] = v,
                onSubmit: _submitFeedback,
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

/// Bloco de feedback subjetivo do user (chips + note opcional). Mesmo set
/// de chips que vinha da página de checkpoint solto — agora vinculado à
/// corrida. Server agrega o feedback das runs da semana no cron de domingo
/// pra propor revisão das próximas 2 semanas.
class _FeedbackBlock extends StatelessWidget {
  final dynamic palette;
  final Set<CheckpointInputKind> selected;
  final Map<CheckpointInputKind, String> notes;
  final bool saved;
  final bool saving;
  final String? error;
  final void Function(CheckpointInputKind) onToggle;
  final void Function(CheckpointInputKind, String) onNoteChanged;
  final VoidCallback onSubmit;

  const _FeedbackBlock({
    required this.palette,
    required this.selected,
    required this.notes,
    required this.saved,
    required this.saving,
    required this.error,
    required this.onToggle,
    required this.onNoteChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
        color: palette.primary.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '> COMO FOI ESSA CORRIDA?',
            style: type.labelCaps.copyWith(color: palette.primary, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          Text(
            'Sua leitura subjetiva entra no ajuste do plano que o coach faz aos domingos — '
            'serve pras próximas 2 semanas.',
            style: type.bodySm.copyWith(
              color: palette.text.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CheckpointInputKind.values
                .map((k) => _FeedbackChip(
                      kind: k,
                      selected: selected.contains(k),
                      onTap: () => onToggle(k),
                      palette: palette,
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          ...selected
              .where((k) => k.requiresNote)
              .map((k) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FeedbackNoteField(
                      label: k.label,
                      hint: k.hint,
                      initialValue: notes[k] ?? '',
                      palette: palette,
                      onChanged: (v) => onNoteChanged(k, v),
                    ),
                  )),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: type.bodySm.copyWith(
                color: const Color(0xFFFF6B35),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (saved) ...[
            const SizedBox(height: 4),
            Text(
              'Feedback salvo. Você pode atualizar enquanto a tela estiver aberta.',
              style: type.bodySm.copyWith(
                color: palette.primary.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: saving ? null : onSubmit,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.primary),
                foregroundColor: palette.primary,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: palette.primary,
                      ),
                    )
                  : Text(
                      saved ? 'ATUALIZAR FEEDBACK' : 'ENVIAR FEEDBACK',
                      style: type.labelMd.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final CheckpointInputKind kind;
  final bool selected;
  final VoidCallback onTap;
  final dynamic palette;

  const _FeedbackChip({
    required this.kind,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.primary : palette.muted;
    final bg = selected
        ? palette.primary.withValues(alpha: 0.14)
        : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          kind.label,
          style: context.runninType.bodySm.copyWith(
            color: selected ? palette.text : palette.muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _FeedbackNoteField extends StatelessWidget {
  final String label;
  final String hint;
  final String initialValue;
  final dynamic palette;
  final ValueChanged<String> onChanged;

  const _FeedbackNoteField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '> ${label.toUpperCase()}',
          style: type.labelCaps.copyWith(
            color: palette.secondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          maxLength: 280,
          minLines: 1,
          maxLines: 3,
          onChanged: onChanged,
          style: type.bodyMd.copyWith(color: palette.text, fontSize: 13),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: type.bodySm.copyWith(color: palette.muted, fontSize: 12.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.primary, width: 1.2),
            ),
          ),
        ),
      ],
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
