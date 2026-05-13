import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/features/coach/domain/entities/coach_report.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/run_share_card.dart';

class ReportPage extends StatefulWidget {
  final String runId;
  const ReportPage({super.key, required this.runId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _remote = RunRemoteDatasource();
  final _coachReportDs = CoachReportRemoteDatasource();
  Run? _run;
  CoachReport? _coachReport;
  bool _loadingRun = true;
  bool _loadingReport = true;
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
      if (mounted) {
        setState(() {
          _run = run;
          _loadingRun = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  Future<void> _pollReport() async {
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (attempts++ > 20) {
        timer.cancel();
        if (mounted) setState(() => _loadingReport = false);
        return;
      }
      try {
        final report = await _coachReportDs.getReport(widget.runId);
        if (report.isReady && mounted) {
          timer.cancel();
          setState(() {
            _coachReport = report;
            _loadingReport = false;
          });
        } else if (report.status == 'ready' && !report.isReady && mounted) {
          timer.cancel();
          setState(() => _loadingReport = false);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _showShareSheet() {
    if (_run == null) return;

    final palette = context.runninPalette;
    final type = context.runninType;

    final data = RunShareCardData(
      distance: (_run!.distanceM / 1000).toStringAsFixed(2),
      duration: _fmtDuration(_run!.durationS),
      pace: _run!.avgPace ?? '--:--',
      targetPace: _run!.targetPace,
      targetDistance: _run!.targetDistance,
      runType: _run!.type,
      xpEarned: _run!.xpEarned,
      coachSummary: _coachReport?.summary,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(
            top: BorderSide(color: palette.border),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'COMPARTILHAR CORRIDA',
              style: type.displaySm.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: RunShareCard(
                data: data,
                palette: palette,
                typography: type,
                scale: 0.85,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  shareRunResult(data);
                },
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('COMPARTILHAR'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('RELATORIO'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_run != null)
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share_outlined),
              onPressed: _showShareSheet,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CORRIDA CONCLUIDA',
                  style: type.labelCaps.copyWith(color: palette.primary),
                ),
                const Spacer(),
                if (_loadingRun)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            if (_loadingRun)
              Center(
                child: CircularProgressIndicator(
                  color: palette.primary,
                  strokeWidth: 2,
                ),
              )
            else if (_run != null)
              _EnhancedStatsRow(run: _run!, palette: palette, type: type),

            if (_run != null) ...[
              const SizedBox(height: 24),

              if (_run!.xpEarned != null && _run!.xpEarned! > 0)
                _XpBadge(xp: _run!.xpEarned!),

              if (_run!.xpEarned != null && _run!.xpEarned! > 0)
                const SizedBox(height: 24),

              if (_run!.type != 'Free Run' && _run!.targetPace != null) ...[
                _TargetRow(run: _run!, palette: palette, type: type),
                const SizedBox(height: 24),
              ],

              CoachNarrativeCard(
                text: _coachReport?.summary ??
                    (_loadingReport ? '' : 'Relatorio nao disponivel.'),
                isLoading: _loadingReport,
                borderColor: palette.secondary,
              ),
            ],

            const SizedBox(height: 32),

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

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _EnhancedStatsRow extends StatelessWidget {
  final Run run;
  final RunninPalette palette;
  final RunninTypography type;

  const _EnhancedStatsRow({
    required this.run,
    required this.palette,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Text(
            (run.distanceM / 1000).toStringAsFixed(2),
            style: type.dataXl.copyWith(fontSize: 64, height: 1.0),
          ),
          Text('km', style: type.labelCaps.copyWith(color: palette.muted)),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatCell(
                label: 'TEMPO',
                value: _fmt(run.durationS),
                unit: '',
                palette: palette,
                type: type,
              ),
              _Divider(palette: palette),
              _StatCell(
                label: 'PACE MED.',
                value: run.avgPace ?? '--:--',
                unit: '/km',
                palette: palette,
                type: type,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StatCell extends StatelessWidget {
  final String label, value, unit;
  final RunninPalette palette;
  final RunninTypography type;

  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.palette,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: type.labelCaps),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: value,
              style: type.dataMd,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(text: ' $unit', style: type.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final RunninPalette palette;

  const _Divider({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: palette.border);
  }
}

class _XpBadge extends StatelessWidget {
  final int xp;

  const _XpBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
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
            '+$xp XP',
            style: TextStyle(
              color: palette.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final Run run;
  final RunninPalette palette;
  final RunninTypography type;

  const _TargetRow({
    required this.run,
    required this.palette,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 16, color: palette.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alvo: ${run.targetPace ?? "--"} pace ${run.targetDistance ?? "--"} km',
              style: type.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
