import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/history/presentation/widgets/hist_stat_card.dart';
import 'package:runnin/features/history/presentation/widgets/runs_list_view.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _Period { week, month, threeMonths }

enum _ContentTab { data, runs }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _allRuns;
  bool _loading = true;
  String? _error;
  _Period _period = _Period.month;
  _ContentTab _tab = _ContentTab.data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final runs = await _remote.listRuns(limit: 90);
      if (mounted) setState(() { _allRuns = runs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar corridas.'; _loading = false; });
    }
  }

  List<Run> get _filteredRuns {
    if (_allRuns == null) return [];
    final cutoff = switch (_period) {
      _Period.week       => DateTime.now().subtract(const Duration(days: 7)),
      _Period.month      => DateTime.now().subtract(const Duration(days: 30)),
      _Period.threeMonths => DateTime.now().subtract(const Duration(days: 90)),
    };
    return _allRuns!
        .where((r) {
          final d = DateTime.tryParse(r.createdAt);
          return d != null && d.isAfter(cutoff);
        })
        .where((r) => r.status == 'completed')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'HISTÓRICO'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['SEMANA', 'MÊS', '3 MESES'],
                selectedIndex: _Period.values.indexOf(_period),
                onChanged: (i) => setState(() => _period = _Period.values[i]),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['DADOS', 'CORRIDAS'],
                selectedIndex: _ContentTab.values.indexOf(_tab),
                onChanged: (i) => setState(() => _tab = _ContentTab.values[i]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final palette = context.runninPalette;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: TextStyle(color: palette.muted)),
        const SizedBox(height: 16),
        TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
      ]));
    }

    final runs = _filteredRuns;

    if (runs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_run_outlined, size: 40, color: palette.border),
        const SizedBox(height: 12),
        Text('Nenhuma corrida no período.', style: TextStyle(color: palette.muted)),
      ]));
    }

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: _load,
      child: _tab == _ContentTab.data
          ? HistStatCard(runs: runs)
          : RunsListView(runs: runs),
    );
  }
}
