import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Vista detalhada do plano com:
///  - Estratégia do coach (markdown gerado pela IA quando disponível)
///  - Dados do perfil considerados (deterministicamente do UserProfile)
///  - Resumo numérico do plano (semanas, volume, distribuição)
///  - Plano semana a semana com sessões + pace + notas
///
/// Rotada via /training/plan-detail.
class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({super.key});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  final _planDs = PlanRemoteDatasource();
  final _userDs = UserRemoteDatasource();
  Plan? _plan;
  UserProfile? _profile;
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
        _planDs.getCurrentPlan(),
        _userDs.getMe(),
      ]);
      if (mounted) setState(() {
        _plan = results[0] as Plan?;
        _profile = results[1] as UserProfile?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const RunninAppBar(title: 'PLANO COMPLETO', fallbackRoute: '/training'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: palette.error)),
                ))
              : _plan == null
                  ? Center(child: Text(
                      'Nenhum plano ativo. Gere um plano em TREINO.',
                      style: TextStyle(color: palette.muted),
                    ))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: palette.primary,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                        children: [
                          _Header(plan: _plan!, profile: _profile),
                          const SizedBox(height: 24),
                          _CoachRationaleCard(plan: _plan!),
                          const SizedBox(height: 24),
                          _ProfileSummary(profile: _profile),
                          const SizedBox(height: 24),
                          _StatsSection(plan: _plan!),
                          const SizedBox(height: 24),
                          _WeeksBreakdown(plan: _plan!),
                        ],
                      ),
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  final Plan plan;
  final UserProfile? profile;
  const _Header({required this.plan, this.profile});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.primary.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OBJETIVO',
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted,
                fontSize: 10,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: 6),
          Text(plan.goal,
              style: GoogleFonts.jetBrainsMono(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _PillStat(label: 'Nível', value: plan.level),
              _PillStat(label: 'Duração', value: '${plan.weeksCount} sem'),
              _PillStat(label: 'Sessões',
                  value: '${plan.weeks.fold<int>(0, (s, w) => s + w.sessions.length)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label;
  final String value;
  const _PillStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: palette.muted, fontSize: 9, letterSpacing: 1.0,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.jetBrainsMono(
              color: palette.text, fontSize: 13, fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}

class _CoachRationaleCard extends StatelessWidget {
  final Plan plan;
  const _CoachRationaleCard({required this.plan});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final rationale = plan.coachRationale;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text('RACIONAL DO COACH',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.primary, fontSize: 11, letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (rationale == null || rationale.isEmpty)
            Text(
              'O coach está escrevendo a análise detalhada do seu plano. Volte em alguns minutos.',
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
            )
          else
            _MarkdownText(rationale),
        ],
      ),
    );
  }
}

/// Render markdown leve: headings (##, ###), bullets (- ), bold (**x**),
/// itálico (*x*). Suficiente pra o output do nosso prompt sem dep externa.
class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText(this.text);
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final lines = text.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(line.substring(4),
              style: GoogleFonts.jetBrainsMono(
                color: palette.text, fontSize: 13, fontWeight: FontWeight.w500,
              )),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(line.substring(3),
              style: GoogleFonts.jetBrainsMono(
                color: palette.primary, fontSize: 14, fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              )),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(width: 4, height: 4, color: palette.primary),
              ),
              Expanded(
                child: Text(_stripInlineMarks(line.substring(2)),
                    style: TextStyle(color: palette.text, fontSize: 13, height: 1.5)),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Text(_stripInlineMarks(line),
            style: TextStyle(color: palette.text, fontSize: 13, height: 1.55)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  static String _stripInlineMarks(String s) =>
      s.replaceAll(RegExp(r'\*\*'), '').replaceAll(RegExp(r'(?<!\w)\*(?!\w)'), '');
}

class _ProfileSummary extends StatelessWidget {
  final UserProfile? profile;
  const _ProfileSummary({this.profile});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    final items = <(String, String)>[
      ('Nível', p.level),
      ('Objetivo', p.goal),
      ('Frequência', '${p.frequency}x/semana'),
      if (p.runPeriod != null) ('Período', p.runPeriod!),
      if (p.weight != null && p.weight!.isNotEmpty) ('Peso', p.weight!),
      if (p.height != null && p.height!.isNotEmpty) ('Altura', p.height!),
      if (p.restingBpm != null) ('FC repouso', '${p.restingBpm} bpm'),
      if (p.maxBpm != null) ('FC máx', '${p.maxBpm} bpm'),
      if ((p.medicalConditions ?? []).isNotEmpty)
        ('Condições', (p.medicalConditions ?? []).join(', ')),
      ('Wearable', p.hasWearable ? 'conectado' : 'sem'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DADOS CONSIDERADOS',
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted, fontSize: 11, letterSpacing: 1.2,
              )),
          const SizedBox(height: 10),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(e.$1,
                          style: TextStyle(color: palette.muted, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(e.$2,
                          style: TextStyle(color: palette.text, fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final Plan plan;
  const _StatsSection({required this.plan});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final totalKm = plan.weeks.fold<double>(
      0, (s, w) => s + w.sessions.fold<double>(0, (ss, x) => ss + x.distanceKm));
    final byType = <String, int>{};
    for (final w in plan.weeks) {
      for (final s in w.sessions) {
        byType.update(s.type, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final typeLines = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VOLUME TOTAL',
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted, fontSize: 11, letterSpacing: 1.2,
              )),
          const SizedBox(height: 6),
          Text('${totalKm.toStringAsFixed(0)} km em ${plan.weeksCount} semanas',
              style: GoogleFonts.jetBrainsMono(
                color: palette.text, fontSize: 16, fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 12),
          Text('DISTRIBUIÇÃO POR TIPO',
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted, fontSize: 11, letterSpacing: 1.2,
              )),
          const SizedBox(height: 6),
          ...typeLines.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key,
                        style: TextStyle(color: palette.text, fontSize: 12))),
                    Text('${e.value}x',
                        style: TextStyle(color: palette.primary, fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _WeeksBreakdown extends StatelessWidget {
  final Plan plan;
  const _WeeksBreakdown({required this.plan});
  static const _dayNames = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PLANO SEMANA A SEMANA',
            style: GoogleFonts.jetBrainsMono(
              color: palette.muted, fontSize: 11, letterSpacing: 1.2,
            )),
        const SizedBox(height: 8),
        ...plan.weeks.map((w) {
          final wKm = w.sessions.fold<double>(0, (s, x) => s + x.distanceKm);
          final sorted = [...w.sessions]
            ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Semana ${w.weekNumber}',
                        style: GoogleFonts.jetBrainsMono(
                          color: palette.text, fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                    const Spacer(),
                    Text('${wKm.toStringAsFixed(0)} km',
                        style: TextStyle(color: palette.primary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ...sorted.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(_dayNames[s.dayOfWeek],
                                style: TextStyle(
                                  color: palette.muted, fontSize: 11,
                                )),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s.type} · ${s.distanceKm.toStringAsFixed(1)} km'
                                    '${s.targetPace != null ? " · ${s.targetPace}/km" : ""}',
                                    style: TextStyle(
                                      color: palette.text, fontSize: 12,
                                    )),
                                if (s.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(s.notes,
                                        style: TextStyle(
                                          color: palette.muted, fontSize: 11,
                                          height: 1.4,
                                        )),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          );
        }),
      ],
    );
  }
}
