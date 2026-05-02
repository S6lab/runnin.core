import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

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
      if (mounted) setState(() { _run = run; _loadingRun = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  Future<void> _pollReport() async {
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (attempts++ > 10) {
        timer.cancel();
        if (mounted) setState(() => _loadingReport = false);
        return;
      }
      try {
        final res = await apiClient.get('/coach/report/${widget.runId}');
        final data = res.data as Map<String, dynamic>;
        if (data['status'] == 'ready') {
          timer.cancel();
          if (mounted) setState(() { _summary = data['summary'] as String?; _loadingReport = false; });
        }
      } catch (_) {}
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

            // Coach narrative card
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
                    style: context.runninType.labelCaps.copyWith(color: palette.secondary),
                  ),
                  const SizedBox(height: 8),
                  _loadingReport
                    ? Row(children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Analisando sua corrida...',
                          style: context.runninType.bodySm,
                        ),
                      ])
                    : Text(
                        _summary ?? 'Relatório não disponível.',
                        style: context.runninType.bodyMd.copyWith(height: 1.6),
                      ),
                ],
              ),
            ),

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
