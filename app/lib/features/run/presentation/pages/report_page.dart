import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/post_run_stat_card.dart';
import 'package:runnin/shared/widgets/coach_ai_card.dart';

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
        final response = await apiClient.get('/coach/report/${widget.runId}');
        final data = response.data as Map<String, dynamic>;
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
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CORRIDA CONCLUÍDA',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.12,
                  height: 1.2,
                  color: Color(0xFF00D4FF),
                ),
              ),
              const SizedBox(height: 24),

              if (_loadingRun)
                Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
              else if (_run != null)
                PostRunStatCard(
                  label: 'DISTÂNCIA',
                  value: (_run!.distanceM / 1000).toStringAsFixed(2),
                  unit: 'km',
                ),
              
              if (_run != null) const SizedBox(height: 8),
              
              if (_run != null)
                PostRunStatCard(
                  label: 'TEMPO',
                  value: _fmt(_run!.durationS),
                  unit: '',
                ),
              
              if (_run != null) const SizedBox(height: 8),
              
              if (_run!.avgPace != null)
                PostRunStatCard(
                  label: 'PACE MÉD.',
                  value: _run!.avgPace!,
                  unit: '/km',
                ),

              if (_run?.xpEarned != null && _run!.xpEarned! > 0)
                const SizedBox(height: 24),

              if (_run?.xpEarned != null && _run!.xpEarned! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 14, color: Color(0xFF00D4FF)),
                      const SizedBox(width: 6),
                      Text(
                        '+${_run!.xpEarned!} XP',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_run?.xpEarned != null && _run!.xpEarned! > 0)
                const SizedBox(height: 24),

              if (_summary != null || _loadingReport)
                CoachAICard(
                  title: 'COACH.AI',
                  borderColor: palette.secondary,
                  children: [
                    _loadingReport
                      ? Row(children: [
                          SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Analisando sua corrida...',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                            ),
                          ),
                        ])
                      : Text(
                          _summary ?? 'Relatório não disponível.',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                  ],
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
      ),
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
