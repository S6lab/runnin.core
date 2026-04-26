import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _remote = RunRemoteDatasource();
  List<Run>? _runs;
  bool _loading = true;
  String? _error;

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
      final runs = await _remote.listRuns(limit: 30);
      if (mounted) {
        setState(() {
          _runs = runs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar corridas.';
          _loading = false;
        });
      }
    }
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
            const SizedBox(height: 20),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final palette = context.runninPalette;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: palette.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: palette.muted)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      );
    }

    if (_runs == null || _runs!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run_outlined,
              size: 40,
              color: palette.border,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma corrida ainda.',
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Vá para Home e inicie seu primeiro treino!',
              style: TextStyle(color: palette.border, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _runs!.length,
        itemBuilder: (_, index) => _RunCard(run: _runs![index]),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final Run run;

  const _RunCard({required this.run});

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String _formatDate(String iso) {
    try {
      final dateTime = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM', 'pt_BR').format(dateTime);
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final distanceKm = (run.distanceM / 1000).toStringAsFixed(2);
    final date = _formatDate(run.createdAt);

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              date.replaceAll(' ', '\n'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: palette.muted, height: 1.3),
            ),
          ),
          const SizedBox(width: 12),
          AppTag(label: run.type.toUpperCase()),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                _MiniStat(value: distanceKm, unit: 'km'),
                const SizedBox(width: 16),
                _MiniStat(value: _formatDuration(run.durationS), unit: ''),
                if (run.avgPace != null) ...[
                  const SizedBox(width: 16),
                  _MiniStat(value: run.avgPace!, unit: '/km'),
                ],
              ],
            ),
          ),
          if (run.xpEarned != null && run.xpEarned! > 0)
            Text(
              '+${run.xpEarned}xp',
              style: TextStyle(
                fontSize: 11,
                color: palette.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String unit;

  const _MiniStat({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return RichText(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: palette.text,
        ),
        children: [
          if (unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: TextStyle(
                fontSize: 10,
                color: palette.muted,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
