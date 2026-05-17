import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/training/data/datasources/checkpoint_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Página de Checkpoint Semanal.
/// Rota: /training/checkpoint/:planId/:weekNumber
///
/// Disclaimer + chips de input + textarea opcional + APLICAR (premium).
/// Mostra `autoAnalysis` se o checkpoint já foi aberto antes.
class CheckpointPage extends StatefulWidget {
  final String planId;
  final int weekNumber;
  const CheckpointPage({
    super.key,
    required this.planId,
    required this.weekNumber,
  });

  @override
  State<CheckpointPage> createState() => _CheckpointPageState();
}

class _CheckpointPageState extends State<CheckpointPage> {
  final _ds = CheckpointRemoteDatasource();
  final _noteCtrl = TextEditingController();

  PlanCheckpoint? _checkpoint;
  bool _loading = true;
  bool _applying = false;
  String? _error;
  String? _applyError;
  String? _coachExplanation;
  final Set<CheckpointInputKind> _selectedKinds = {};
  final Map<CheckpointInputKind, String> _kindNotes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cp = await _ds.getOne(widget.planId, widget.weekNumber);
      if (!mounted) return;
      if (cp == null) {
        setState(() {
          _error = 'Checkpoint não encontrado pra essa semana.';
          _loading = false;
        });
        return;
      }
      // Repopula seleção com inputs já submetidos
      for (final i in cp.userInputs) {
        _selectedKinds.add(i.kind);
        if (i.note != null) _kindNotes[i.kind] = i.note!;
      }
      setState(() {
        _checkpoint = cp;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar checkpoint.';
        _loading = false;
      });
    }
  }

  List<CheckpointInput> _buildInputs() {
    return _selectedKinds.map((k) {
      final note = _kindNotes[k]?.trim();
      return CheckpointInput(
        kind: k,
        note: note != null && note.isNotEmpty ? note : null,
      );
    }).toList();
  }

  bool _validInputs() {
    for (final k in _selectedKinds) {
      if (k.requiresNote) {
        final note = _kindNotes[k]?.trim();
        if (note == null || note.isEmpty) return false;
      }
    }
    return true;
  }

  Future<void> _apply() async {
    if (!_validInputs()) {
      setState(() {
        _applyError = 'Detalhe os itens marcados como "dor" ou "outro".';
      });
      return;
    }
    setState(() {
      _applying = true;
      _applyError = null;
    });
    try {
      final result = await _ds.apply(
        widget.planId,
        widget.weekNumber,
        _buildInputs(),
      );
      if (!mounted) return;
      setState(() {
        _checkpoint = result.checkpoint;
        _coachExplanation = result.coachExplanation;
        _applying = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      final body = e.response?.data is Map ? e.response!.data as Map : null;
      String msg;
      if (code == 403) {
        msg =
            'Ajuste do plano via checkpoint é recurso premium. Assine pra desbloquear.';
      } else if (code == 409) {
        msg = 'Esse checkpoint já foi aplicado — só 1 ajuste por semana.';
      } else if (code == 422) {
        msg = 'Plano não está pronto. Aguarde geração concluir.';
      } else {
        msg = (body?['message'] as String?) ?? 'Erro ao aplicar checkpoint.';
      }
      setState(() {
        _applyError = msg;
        _applying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applyError = 'Erro inesperado.';
        _applying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: RunninAppBar(
        title: 'CHECKPOINT · SEM ${widget.weekNumber}',
        onBack: () => context.pop(),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: palette.primary),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildContent(palette),
    );
  }

  Widget _buildContent(RunninPalette palette) {
    final cp = _checkpoint!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DisclaimerCard(),
          const SizedBox(height: 16),
          _MetaRow(checkpoint: cp),
          const SizedBox(height: 16),
          if (cp.autoAnalysis != null && cp.autoAnalysis!.trim().isNotEmpty) ...[
            _Section(
              title: '> ANÁLISE DA SEMANA',
              child: Text(
                cp.autoAnalysis!,
                style: TextStyle(
                  color: palette.text.withValues(alpha: 0.86),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (cp.isCompleted) ...[
            _CompletedBanner(checkpoint: cp),
            if (_coachExplanation != null) ...[
              const SizedBox(height: 16),
              _Section(
                title: '> RACIONAL DO AJUSTE',
                child: Text(
                  _coachExplanation!,
                  style: TextStyle(
                    color: palette.text.withValues(alpha: 0.86),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ] else ...[
            _Section(
              title: '> COMO VOCÊ TÁ?',
              child: _ChipsGrid(
                selected: _selectedKinds,
                onToggle: (k) => setState(() {
                  if (_selectedKinds.contains(k)) {
                    _selectedKinds.remove(k);
                    _kindNotes.remove(k);
                  } else {
                    _selectedKinds.add(k);
                  }
                }),
              ),
            ),
            const SizedBox(height: 16),
            ..._selectedKinds
                .where((k) => k.requiresNote)
                .map((k) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NoteField(
                        label: k.label,
                        hint: k.hint,
                        initialValue: _kindNotes[k] ?? '',
                        onChanged: (v) => _kindNotes[k] = v,
                      ),
                    )),
            if (_applyError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _applyError!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _applying ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'APLICAR AJUSTE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ao aplicar, o coach ajusta as semanas seguintes do plano. Você pode usar 1x por semana.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      borderColor: palette.primary.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '> REGRA DO CHECKPOINT',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seu plano é ajustável 1x por semana — no checkpoint. O coach lê tudo que você fez (corridas, pace, BPM, aderência) e cruza com o que você marcar aqui. As semanas SEGUINTES são recalculadas; o passado fica como referência.',
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final PlanCheckpoint checkpoint;
  const _MetaRow({required this.checkpoint});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final statusLabel = switch (checkpoint.status) {
      'completed' => 'APLICADO',
      'in_progress' => 'EM EDIÇÃO',
      'skipped' => 'EXPIRADO',
      _ => 'ABERTO',
    };
    final statusColor = checkpoint.status == 'completed'
        ? palette.primary
        : checkpoint.status == 'skipped'
            ? palette.muted
            : palette.secondary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: statusColor.withValues(alpha: 0.15),
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: statusColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Vence ${checkpoint.scheduledDate}',
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.1,
            color: palette.secondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ChipsGrid extends StatelessWidget {
  final Set<CheckpointInputKind> selected;
  final void Function(CheckpointInputKind) onToggle;
  const _ChipsGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CheckpointInputKind.values
          .map((k) => _ChipBtn(
                kind: k,
                selected: selected.contains(k),
                onTap: () => onToggle(k),
              ))
          .toList(),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final CheckpointInputKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _ChipBtn({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
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
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        ),
        child: Text(
          kind.label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? palette.text : palette.muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  const _NoteField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '> ${label.toUpperCase()}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
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
          style: TextStyle(color: palette.text, fontSize: 13),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: TextStyle(color: palette.muted, fontSize: 12.5),
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

class _CompletedBanner extends StatelessWidget {
  final PlanCheckpoint checkpoint;
  const _CompletedBanner({required this.checkpoint});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      borderColor: palette.primary.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '> AJUSTE APLICADO',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.1,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O coach já ajustou as semanas seguintes do seu plano com base nos inputs e nos seus dados. Próximo checkpoint disponível na próxima semana.',
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          if (checkpoint.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Aplicado em ${checkpoint.completedAt!.substring(0, 10)}',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: FigmaColors.brandCyan),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text(
                'TENTAR DE NOVO',
                style: TextStyle(
                  color: FigmaColors.brandCyan,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
