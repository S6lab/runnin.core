import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

class RunDetailPage extends StatefulWidget {
  final String runId;
  const RunDetailPage({super.key, required this.runId});

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage> {
  final _remote = RunRemoteDatasource();
  Run? _run;
  String? _summary;
  bool _loadingRun = true;
  bool _loadingReport = true;

  @override
  void initState() {
    super.initState();
    _loadRun();
    _loadReport();
  }

  Future<void> _loadRun() async {
    try {
      final run = await _remote.getRun(widget.runId);
      if (mounted) setState(() { _run = run; _loadingRun = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  Future<void> _loadReport() async {
    try {
      final res = await apiClient.get('/coach/report/${widget.runId}');
      final data = res.data as Map<String, dynamic>;
      if (data['status'] == 'ready') {
        if (mounted) setState(() { _summary = data['summary'] as String?; _loadingReport = false; });
      } else {
        if (mounted) setState(() => _loadingReport = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat("dd 'de' MMMM, yyyy", 'pt_BR').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: FigmaDimensions.backButton,
                      height: FigmaDimensions.backButton,
                      decoration: BoxDecoration(
                        border: Border.all(color: FigmaColors.borderBackBtn, width: FigmaDimensions.borderUniversal),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: palette.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('DETALHE DA CORRIDA', style: type.labelCaps),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _loadingRun
                  ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
                  : _run == null
                      ? Center(child: Text('Corrida não encontrada.', style: TextStyle(color: palette.muted)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date & type
                              Text(
                                _fmtDate(_run!.createdAt).toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1.1,
                                  color: FigmaColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                color: palette.primary.withValues(alpha: 0.15),
                                child: Text(
                                  _run!.type.toUpperCase(),
                                  style: type.labelCaps.copyWith(color: palette.primary),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Stats tiles
                              _StatsTiles(run: _run!),
                              const SizedBox(height: 20),

                              // XP badge
                              if (_run!.xpEarned != null && _run!.xpEarned! > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                        '+${_run!.xpEarned} XP',
                                        style: type.labelMd.copyWith(color: palette.primary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Coach AI analysis
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: palette.secondary, width: 3)),
                                  color: palette.secondary.withValues(alpha: 0.05),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COACH.AI',
                                      style: type.labelCaps.copyWith(color: palette.secondary),
                                    ),
                                    const SizedBox(height: 8),
                                    _loadingReport
                                        ? Row(children: [
                                            SizedBox(
                                              width: 12, height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
                                            ),
                                            const SizedBox(width: 10),
                                            Text('Carregando análise...', style: type.bodySm),
                                          ])
                                        : Text(
                                            _summary ?? 'Relatório não disponível para esta corrida.',
                                            style: type.bodyMd.copyWith(height: 1.6),
                                          ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Splits placeholder
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: FigmaColors.surfaceCard,
                                  border: Border.all(color: palette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SPLITS', style: type.labelCaps.copyWith(color: palette.primary)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Dados de splits por km serão exibidos aqui.',
                                      style: type.bodySm.copyWith(color: FigmaColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // CTAs
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/share', extra: {'runId': widget.runId}),
                                  icon: Icon(Icons.share_outlined, size: 16, color: palette.primary),
                                  label: Text('COMPARTILHAR', style: type.labelCaps.copyWith(color: palette.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: const RoundedRectangleBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push('/history/run/${widget.runId}/conversa'),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                  label: Text('VER CONVERSA COM COACH', style: type.labelCaps),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: const RoundedRectangleBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsTiles extends StatelessWidget {
  final Run run;
  const _StatsTiles({required this.run});

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
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
          _StatCell(label: 'DISTÂNCIA', value: (run.distanceM / 1000).toStringAsFixed(2), unit: 'km'),
          Container(width: 1, height: 40, color: palette.border),
          _StatCell(label: 'TEMPO', value: _fmtDuration(run.durationS), unit: ''),
          Container(width: 1, height: 40, color: palette.border),
          _StatCell(label: 'PACE MÉD.', value: run.avgPace ?? '--:--', unit: '/km'),
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
            children: [if (unit.isNotEmpty) TextSpan(text: ' $unit', style: type.bodySm)],
          )),
        ],
      ),
    );
  }
}
