import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/features/coach/domain/entities/coach_report.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';

class RunDetailPage extends StatefulWidget {
  final String runId;
  const RunDetailPage({super.key, required this.runId});

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage> {
  final _runDs = RunRemoteDatasource();
  final _reportDs = CoachReportRemoteDatasource();
  Run? _run;
  CoachReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _runDs.getRun(widget.runId),
        _reportDs.getReport(widget.runId),
      ]);
      if (!mounted) return;
      setState(() {
        _run = results[0] as Run;
        _report = results[1] as CoachReport;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corrida.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.text),
          onPressed: () => context.pop(),
        ),
        title: Text('CORRIDA', style: type.displaySm),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: TextStyle(color: palette.muted)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
                ]))
              : _buildContent(palette, type),
    );
  }

  Widget _buildContent(RunninPalette palette, RunninTypography type) {
    final run = _run!;
    final km = (run.distanceM / 1000).toStringAsFixed(2);
    final date = _fmtDate(run.createdAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + type header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: palette.primary.withValues(alpha: 0.15),
                child: Text(run.type.toUpperCase(), style: type.labelCaps.copyWith(color: palette.primary)),
              ),
              const SizedBox(width: 12),
              Text(date, style: type.bodySm),
            ],
          ),
          const SizedBox(height: 20),

          // Metric grid
          Row(children: [
            Expanded(child: MetricCard(label: 'DISTÂNCIA', value: km, unit: 'km')),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'DURAÇÃO', value: _fmtDuration(run.durationS))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: MetricCard(label: 'PACE MÉD.', value: run.avgPace ?? '--:--', unit: '/km')),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'BPM MÉD.', value: run.avgBpm?.toString() ?? '--', unit: 'bpm')),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'XP', value: '+${run.xpEarned ?? 0}')),
          ]),
          const SizedBox(height: 24),

          // Full Coach analysis
          CoachNarrativeCard(
            text: _report?.summary != null && _report!.isReady
                ? _report!.summary!
                : 'Análise do Coach ainda não disponível para esta corrida.',
            borderColor: palette.primary,
          ),
          const SizedBox(height: 24),

          // Splits placeholder
          Text('SPLITS', style: type.displaySm),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('KM', style: type.labelCaps)),
                    Expanded(child: Text('TEMPO', style: type.labelCaps, textAlign: TextAlign.center)),
                    Expanded(child: Text('PACE', style: type.labelCaps, textAlign: TextAlign.right)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_splitsFromRun(run).length, (i) {
                  final split = _splitsFromRun(run)[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: palette.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('${split.km}', style: type.bodyMd)),
                        Expanded(child: Text(split.time, style: type.bodyMd, textAlign: TextAlign.center)),
                        Expanded(child: Text(split.pace, style: type.bodyMd, textAlign: TextAlign.right)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // CTAs
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareRun(context),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('COMPARTILHAR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/coach-conversation', extra: widget.runId),
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: const Text('COACH.AI'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<_SplitInfo> _splitsFromRun(Run run) {
    if (run.durationS <= 0 || run.distanceM <= 0) return [];
    final totalKm = run.distanceM / 1000;
    final fullKm = totalKm.floor();
    if (fullKm <= 0) return [];

    final timePerKm = run.durationS / totalKm;
    final splits = <_SplitInfo>[];
    for (int i = 0; i < fullKm; i++) {
      final s = (timePerKm * (i + 1)).round();
      final pace = _fmtDuration((timePerKm).round());
      splits.add(_SplitInfo(km: i + 1, time: _fmtDuration(s), pace: pace));
    }
    if (totalKm - fullKm > 0.05) {
      final lastKm = fullKm + 1;
      final s = run.durationS.round();
      splits.add(_SplitInfo(km: lastKm, time: _fmtDuration(s), pace: '${_fmtDuration((timePerKm).round())}/km'));
    }
    return splits;
  }

  void _shareRun(BuildContext context) {
    final run = _run!;
    final km = (run.distanceM / 1000).toStringAsFixed(2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Corrida de $km km — funcionalidade de compartilhar em breve.')),
    );
  }

  String _fmtDate(String iso) {
    try { return DateFormat("dd 'de' MMMM, yyyy").format(DateTime.parse(iso).toLocal()); }
    catch (_) { return iso.substring(0, 10); }
  }

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _SplitInfo {
  final int km;
  final String time;
  final String pace;
  const _SplitInfo({required this.km, required this.time, required this.pace});
}
