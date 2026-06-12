import 'package:flutter/material.dart';
import 'package:runnin/features/admin/data/admin_metrics_datasource.dart';

/// Aba TECH do admin — visão de saúde num lugar só: serviços (healthz ao
/// vivo), erros 24h/7d (contador alimentado pelo logger) e custo LLM.
/// Detalhe fino de tokens continua na tela "Tokens & Custo LLM".
class AdminTechPage extends StatefulWidget {
  const AdminTechPage({super.key});

  @override
  State<AdminTechPage> createState() => _AdminTechPageState();
}

class _AdminTechPageState extends State<AdminTechPage> {
  final _ds = AdminMetricsDatasource();
  TechMetrics? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ds.getTech();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TECH · SAÚDE & CUSTOS'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Erro: $_error'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _servicesCard(),
                      const SizedBox(height: 12),
                      _errorsCard(),
                      const SizedBox(height: 12),
                      _costCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _servicesCard() {
    final services = _data!.services;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SERVIÇOS', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            for (final s in services)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      s.ok ? Icons.check_circle : Icons.error,
                      size: 18,
                      color: s.ok ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.name)),
                    Text(
                      s.ok ? '${s.latencyMs ?? '—'}ms' : (s.error ?? 'down'),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorsCard() {
    final d = _data!;
    final today = d.errorsToday;
    final topKeys = (today?.byMessageKey.entries.toList() ?? [])
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ERROS', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                _kpi('HOJE', '${today?.total ?? 0}'),
                const SizedBox(width: 24),
                _kpi('7 DIAS', '${d.errorsTotal7d}'),
              ],
            ),
            if (today != null && today.byService.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                today.byService.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (topKeys.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Top hoje:', style: Theme.of(context).textTheme.bodySmall),
              for (final e in topKeys.take(6))
                Text(
                  '• ${e.key.replaceAll(':', '.')} — ${e.value}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _costCard() {
    final d = _data!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CUSTO LLM', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                _kpi('HOJE', '\$${d.llmCostTodayUsd.toStringAsFixed(2)}'),
                const SizedBox(width: 24),
                _kpi('7 DIAS', '\$${d.llmCost7dUsd.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Detalhe por modelo/use-case/top users: tela "Tokens & Custo LLM".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}
