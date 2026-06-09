import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_usage_datasource.dart';

/// Console de gasto LLM — tokens input/output + custo USD agregado por
/// dia, modelo, use case. Lê de `users/{uid}/llm_usage/{date}` (per-user)
/// e `system/llm_usage/daily/{date}` (crons). Pricing hardcoded em
/// `server/src/shared/infra/llm/llm-pricing.ts`.
class AdminTokensPage extends StatefulWidget {
  const AdminTokensPage({super.key});

  @override
  State<AdminTokensPage> createState() => _AdminTokensPageState();
}

enum _RangePreset { today, last7d, last30d }

class _AdminTokensPageState extends State<AdminTokensPage> {
  final _ds = AdminUsageDatasource();
  _RangePreset _preset = _RangePreset.last7d;
  bool _includeSystem = true;
  UsageBreakdown _users = UsageBreakdown.empty;
  UsageBreakdown _system = UsageBreakdown.empty;
  List<TopUserUsage> _topUsers = const [];
  Map<String, ModelPricing> _pricing = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({String from, String to}) _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fromDate = switch (_preset) {
      _RangePreset.today => today,
      _RangePreset.last7d => today.subtract(const Duration(days: 6)),
      _RangePreset.last30d => today.subtract(const Duration(days: 29)),
    };
    return (from: _fmt(fromDate), to: _fmt(today));
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = _resolveRange();
      final results = await Future.wait([
        _ds.getTokens(from: r.from, to: r.to),
        _ds.topUsers(from: r.from, to: r.to, limit: 20),
        if (_pricing.isEmpty) _ds.getPricing(),
        if (_includeSystem) _ds.getSystemUsage(from: r.from, to: r.to),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as UsageBreakdown;
        _topUsers = results[1] as List<TopUserUsage>;
        var idx = 2;
        if (_pricing.isEmpty) {
          _pricing = results[idx] as Map<String, ModelPricing>;
          idx++;
        }
        if (_includeSystem) {
          _system = results[idx] as UsageBreakdown;
        } else {
          _system = UsageBreakdown.empty;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  UsageBreakdown get _merged {
    if (!_includeSystem) return _users;
    return _mergeBreakdowns(_users, _system);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final m = _merged;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('TOKENS · CUSTO LLM'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RangeBar(
            preset: _preset,
            includeSystem: _includeSystem,
            onPresetChanged: (p) {
              setState(() => _preset = p);
              _load();
            },
            onSystemToggle: (v) {
              setState(() => _includeSystem = v);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.error.withValues(alpha: 0.12),
                border: Border.all(color: palette.error),
              ),
              child: Text(_error!,
                  style: TextStyle(color: palette.error, fontSize: 12)),
            ),
          if (_loading && m.totals.calls == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _KpiGrid(totals: m.totals),
            const SizedBox(height: 16),
            Text('CUSTO POR DIA',
                style:
                    type.labelMd.copyWith(letterSpacing: 0.5, color: palette.text)),
            const SizedBox(height: 8),
            _ByDayList(byDay: m.byDay),
            const SizedBox(height: 16),
            Text('POR MODELO',
                style:
                    type.labelMd.copyWith(letterSpacing: 0.5, color: palette.text)),
            const SizedBox(height: 8),
            _ByModelTable(byModel: m.byModel, pricing: _pricing),
            const SizedBox(height: 16),
            Text('POR USE CASE',
                style:
                    type.labelMd.copyWith(letterSpacing: 0.5, color: palette.text)),
            const SizedBox(height: 8),
            _ByUseCaseTable(byUseCase: m.byUseCase),
            const SizedBox(height: 16),
            Text('TOP USERS · CUSTO',
                style:
                    type.labelMd.copyWith(letterSpacing: 0.5, color: palette.text)),
            const SizedBox(height: 8),
            _TopUsersTable(users: _topUsers),
            const SizedBox(height: 24),
            Text(
              'System: crons (weekly revision, daily push) somam separadamente. Pricing USD/1M tokens hardcoded no server.',
              style: type.bodyXs.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  final _RangePreset preset;
  final bool includeSystem;
  final ValueChanged<_RangePreset> onPresetChanged;
  final ValueChanged<bool> onSystemToggle;

  const _RangeBar({
    required this.preset,
    required this.includeSystem,
    required this.onPresetChanged,
    required this.onSystemToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_RangePreset>(
              segments: const [
                ButtonSegment(value: _RangePreset.today, label: Text('HOJE')),
                ButtonSegment(value: _RangePreset.last7d, label: Text('7D')),
                ButtonSegment(value: _RangePreset.last30d, label: Text('30D')),
              ],
              selected: {preset},
              onSelectionChanged: (s) => onPresetChanged(s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w500),
                ),
                shape: WidgetStateProperty.all(
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              Checkbox(
                value: includeSystem,
                onChanged: (v) => onSystemToggle(v ?? false),
                visualDensity: VisualDensity.compact,
              ),
              Text('crons',
                  style: TextStyle(color: palette.text, fontSize: 11, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final UsageTotals totals;
  const _KpiGrid({required this.totals});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 720 ? 4 : 2;
      const spacing = 10.0;
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(
              width: w,
              child: _KpiCard(label: 'CUSTO USD', value: '\$${totals.costUsd.toStringAsFixed(4)}')),
          SizedBox(
              width: w,
              child: _KpiCard(label: 'TOTAL CALLS', value: _fmtInt(totals.calls))),
          SizedBox(
              width: w,
              child: _KpiCard(
                  label: 'INPUT TOKENS', value: _fmtInt(totals.inputTokens))),
          SizedBox(
              width: w,
              child: _KpiCard(
                  label: 'OUTPUT TOKENS', value: _fmtInt(totals.outputTokens))),
        ],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: palette.muted,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: palette.text,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ByDayList extends StatelessWidget {
  final List<DailyUsage> byDay;
  const _ByDayList({required this.byDay});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (byDay.isEmpty) {
      return Text('Sem dados no período.',
          style: TextStyle(color: palette.muted, fontSize: 11));
    }
    final maxCost = byDay.fold<double>(
        0, (acc, d) => d.totalCostUsd > acc ? d.totalCostUsd : acc);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < byDay.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: i == byDay.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(byDay[i].date,
                        style: TextStyle(
                            color: palette.muted,
                            fontFamily: 'monospace',
                            fontSize: 11)),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: LinearProgressIndicator(
                        value: maxCost > 0
                            ? (byDay[i].totalCostUsd / maxCost).clamp(0, 1)
                            : 0,
                        minHeight: 6,
                        backgroundColor: palette.surfaceAlt,
                        valueColor:
                            AlwaysStoppedAnimation(palette.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '\$${byDay[i].totalCostUsd.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: palette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${byDay[i].totalCalls}c',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ByModelTable extends StatelessWidget {
  final Map<String, ModelUsage> byModel;
  final Map<String, ModelPricing> pricing;
  const _ByModelTable({required this.byModel, required this.pricing});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (byModel.isEmpty) {
      return Text('Sem dados.',
          style: TextStyle(color: palette.muted, fontSize: 11));
    }
    final entries = byModel.entries.toList()
      ..sort((a, b) => b.value.costUsd.compareTo(a.value.costUsd));
    final totalCost = entries.fold<double>(0, (a, b) => a + b.value.costUsd);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: palette.surfaceAlt,
            child: Row(
              children: [
                Expanded(flex: 4, child: _Th('MODELO')),
                Expanded(flex: 2, child: _Th('INPUT', right: true)),
                Expanded(flex: 2, child: _Th('OUTPUT', right: true)),
                Expanded(flex: 2, child: _Th('CALLS', right: true)),
                Expanded(flex: 2, child: _Th('USD', right: true)),
                Expanded(flex: 1, child: _Th('%', right: true)),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: i == entries.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].key,
                            style: TextStyle(
                                color: palette.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        if (pricing[entries[i].key] != null)
                          Text(
                            '\$${pricing[entries[i].key]!.inputPer1M.toStringAsFixed(2)} in / \$${pricing[entries[i].key]!.outputPer1M.toStringAsFixed(2)} out por 1M',
                            style:
                                TextStyle(color: palette.muted, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _fmtInt(entries[i].value.input),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.text, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _fmtInt(entries[i].value.output),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.text, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${entries[i].value.calls}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.text, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${entries[i].value.costUsd.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: palette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      totalCost > 0
                          ? '${(entries[i].value.costUsd / totalCost * 100).toStringAsFixed(0)}%'
                          : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ByUseCaseTable extends StatelessWidget {
  final Map<String, UseCaseUsage> byUseCase;
  const _ByUseCaseTable({required this.byUseCase});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (byUseCase.isEmpty) {
      return Text('Sem dados.',
          style: TextStyle(color: palette.muted, fontSize: 11));
    }
    final entries = byUseCase.entries.toList()
      ..sort((a, b) => b.value.costUsd.compareTo(a.value.costUsd));
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: palette.surfaceAlt,
            child: Row(
              children: [
                Expanded(flex: 4, child: _Th('USE CASE')),
                Expanded(flex: 2, child: _Th('CALLS', right: true)),
                Expanded(flex: 3, child: _Th('USD', right: true)),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: i == entries.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(entries[i].key,
                        style: TextStyle(
                            color: palette.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${entries[i].value.calls}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.text, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '\$${entries[i].value.costUsd.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: palette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopUsersTable extends StatelessWidget {
  final List<TopUserUsage> users;
  const _TopUsersTable({required this.users});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (users.isEmpty) {
      return Text('Sem usuários com gasto no período.',
          style: TextStyle(color: palette.muted, fontSize: 11));
    }
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: palette.surfaceAlt,
            child: Row(
              children: [
                SizedBox(width: 24, child: _Th('#')),
                Expanded(flex: 5, child: _Th('USER ID')),
                Expanded(flex: 2, child: _Th('CALLS', right: true)),
                Expanded(flex: 3, child: _Th('USD', right: true)),
              ],
            ),
          ),
          for (var i = 0; i < users.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: i == users.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}',
                        style: TextStyle(color: palette.muted, fontSize: 11)),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(users[i].userId,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: palette.text,
                            fontFamily: 'monospace',
                            fontSize: 11)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${users[i].calls}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.text, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '\$${users[i].costUsd.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: palette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  final bool right;
  const _Th(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        color: palette.muted,
        fontSize: 9,
        letterSpacing: 1,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

UsageBreakdown _mergeBreakdowns(UsageBreakdown a, UsageBreakdown b) {
  final byModel = <String, ModelUsage>{};
  void addModel(Map<String, ModelUsage> src) {
    for (final e in src.entries) {
      final acc = byModel[e.key];
      byModel[e.key] = ModelUsage(
        input: (acc?.input ?? 0) + e.value.input,
        output: (acc?.output ?? 0) + e.value.output,
        calls: (acc?.calls ?? 0) + e.value.calls,
        costUsd: (acc?.costUsd ?? 0) + e.value.costUsd,
      );
    }
  }

  addModel(a.byModel);
  addModel(b.byModel);

  final byUseCase = <String, UseCaseUsage>{};
  void addUC(Map<String, UseCaseUsage> src) {
    for (final e in src.entries) {
      final acc = byUseCase[e.key];
      byUseCase[e.key] = UseCaseUsage(
        calls: (acc?.calls ?? 0) + e.value.calls,
        costUsd: (acc?.costUsd ?? 0) + e.value.costUsd,
      );
    }
  }

  addUC(a.byUseCase);
  addUC(b.byUseCase);

  final byDay = <String, DailyUsage>{};
  void addDay(List<DailyUsage> src) {
    for (final d in src) {
      final acc = byDay[d.date];
      byDay[d.date] = DailyUsage(
        date: d.date,
        totalInputTokens:
            (acc?.totalInputTokens ?? 0) + d.totalInputTokens,
        totalOutputTokens:
            (acc?.totalOutputTokens ?? 0) + d.totalOutputTokens,
        totalCalls: (acc?.totalCalls ?? 0) + d.totalCalls,
        totalCostUsd: (acc?.totalCostUsd ?? 0) + d.totalCostUsd,
      );
    }
  }

  addDay(a.byDay);
  addDay(b.byDay);
  final sortedDays = byDay.values.toList()
    ..sort((x, y) => x.date.compareTo(y.date));

  return UsageBreakdown(
    totals: UsageTotals(
      inputTokens: a.totals.inputTokens + b.totals.inputTokens,
      outputTokens: a.totals.outputTokens + b.totals.outputTokens,
      calls: a.totals.calls + b.totals.calls,
      costUsd: a.totals.costUsd + b.totals.costUsd,
    ),
    byDay: sortedDays,
    byModel: byModel,
    byUseCase: byUseCase,
  );
}

String _fmtInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
