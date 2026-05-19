import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_split_row.dart';

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
                      ? Center(child: Text('Corrida não encontrada.', style: type.bodySm.copyWith(color: palette.muted)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date & type
                              Text(
                                _fmtDate(_run!.createdAt).toUpperCase(),
                                style: type.bodyXs.copyWith(
                                  letterSpacing: 1.1,
                                  color: FigmaColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                color: palette.primary.withValues(alpha: 0.15),
                                child: Text(
                                  _run!.type.toUpperCase(),
                                  style: type.labelCaps.copyWith(color: palette.primary),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Stats tiles (linha 1: distância/tempo/pace)
                              _StatsTiles(run: _run!),
                              const SizedBox(height: 10),
                              // Stats tiles (linha 2: BPM méd/máx + calorias)
                              _BiometricStatsTiles(run: _run!),
                              const SizedBox(height: 20),

                              // XP badge
                              if (_run!.xpEarned != null && _run!.xpEarned! > 0) ...[
                                Container(
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

                              // Splits
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
                                    const SizedBox(height: 12),
                                    if (_run!.splits.isEmpty)
                                      Text(
                                        'Sem splits por km registrados nesta corrida.',
                                        style: type.bodySm.copyWith(color: FigmaColors.textMuted),
                                      )
                                    else
                                      ..._buildSplitRows(_run!.splits),
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

  /// Monta uma lista de FigmaSplitRow. Best split (menor pace numérico) fica
  /// destacado em cyan via isBest; demais em dim. barRatio = pace/maxPace
  /// (split mais lento ocupa toda a largura, mais rápido proporcionalmente
  /// menos — leitura visual de "mais curto = mais rápido").
  List<Widget> _buildSplitRows(List<KmSplit> splits) {
    final sorted = [...splits]..sort((a, b) => a.kmIndex.compareTo(b.kmIndex));
    final paceMins = sorted.map(_paceToMin).toList();
    final validPaces = paceMins.where((p) => p != null).cast<double>().toList();
    if (validPaces.isEmpty) {
      return sorted
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FigmaSplitRow(
                  kmLabel: 'KM${s.kmIndex + 1}',
                  time: _formatDuration(s.durationS),
                  barRatio: 0,
                  isBest: false,
                  bpm: s.avgBpm,
                  calories: s.calories,
                ),
              ))
          .toList();
    }
    final maxPace = validPaces.reduce((a, b) => a > b ? a : b);
    final bestIdx = paceMins.indexWhere((p) => p != null && p == validPaces.reduce((a, b) => a < b ? a : b));

    return List.generate(sorted.length, (i) {
      final s = sorted[i];
      final p = paceMins[i];
      final ratio = (p != null && maxPace > 0) ? p / maxPace : 0.0;
      return Padding(
        padding: EdgeInsets.only(bottom: i == sorted.length - 1 ? 0 : 6),
        child: FigmaSplitRow(
          kmLabel: 'KM${s.kmIndex + 1}',
          time: s.avgPaceMinKm ?? _formatDuration(s.durationS),
          barRatio: ratio,
          isBest: i == bestIdx,
          bpm: s.avgBpm,
          calories: s.calories,
          elevationGainM: s.elevationGain,
        ),
      );
    });
  }

  double? _paceToMin(KmSplit s) {
    final p = s.avgPaceMinKm;
    if (p == null) return null;
    final parts = p.split(':');
    if (parts.length != 2) return null;
    final min = int.tryParse(parts[0]);
    final sec = int.tryParse(parts[1]);
    if (min == null || sec == null) return null;
    return min + sec / 60.0;
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString();
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
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

/// 2ª linha de stats: BPM médio, BPM máx, calorias. Só renderiza
/// cells com valor — pra runs antigas sem esses campos não fica
/// poluído com "—".
class _BiometricStatsTiles extends StatelessWidget {
  final Run run;
  const _BiometricStatsTiles({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final cells = <Widget>[];
    void addCell(String label, String value, String unit) {
      if (cells.isNotEmpty) {
        cells.add(Container(width: 1, height: 40, color: palette.border));
      }
      cells.add(_StatCell(label: label, value: value, unit: unit));
    }
    if (run.avgBpm != null && run.avgBpm! > 0) {
      addCell('BPM MÉD.', '${run.avgBpm}', 'bpm');
    }
    if (run.maxBpm != null && run.maxBpm! > 0) {
      addCell('BPM MÁX.', '${run.maxBpm}', 'bpm');
    }
    if (run.calories != null && run.calories! > 0) {
      addCell('CALORIAS', '${run.calories}', 'kcal');
    }
    if (cells.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Row(children: cells),
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
