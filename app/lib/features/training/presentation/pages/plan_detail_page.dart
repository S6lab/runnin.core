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
                          // 1. Header com objetivo + stats principais
                          _Header(plan: _plan!, profile: _profile),
                          const SizedBox(height: 14),
                          // 2. Ficha do perfil — dados que o coach considerou
                          _CollapsibleSection(
                            icon: Icons.person_outline,
                            title: 'SEU PERFIL CONSIDERADO',
                            initiallyExpanded: true,
                            child: _ProfileSummary(profile: _profile),
                          ),
                          const SizedBox(height: 10),
                          // 3. Mesociclo (curto)
                          if (_plan!.mesocycleNarrative != null &&
                              _plan!.mesocycleNarrative!.trim().isNotEmpty)
                            _CollapsibleSection(
                              icon: Icons.timeline,
                              title: 'VISÃO DO MESOCICLO',
                              accent: true,
                              child: _MesocycleCard(text: _plan!.mesocycleNarrative!),
                            ),
                          if (_plan!.mesocycleNarrative != null &&
                              _plan!.mesocycleNarrative!.trim().isNotEmpty)
                            const SizedBox(height: 10),
                          // 4. Racional colapsável (por seções ##)
                          _RationaleAccordion(plan: _plan!),
                          const SizedBox(height: 10),
                          // 5. Stats numérico
                          _CollapsibleSection(
                            icon: Icons.bar_chart_outlined,
                            title: 'NÚMEROS DO PLANO',
                            child: _StatsSection(plan: _plan!),
                          ),
                          const SizedBox(height: 10),
                          // 6. Plano semana a semana (1 expansion tile por week)
                          _WeeksBreakdown(plan: _plan!),
                          // 7. Histórico de revisões (se houver)
                          if (_plan!.revisions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _RevisionsSection(revisions: _plan!.revisions),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

/// Wrapper colapsável genérico pras seções da ficha do plano.
/// Mantém visual consistente: header com icon + title + chevron.
class _CollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool accent;
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: accent ? palette.primary.withValues(alpha: 0.05) : palette.surface,
          border: Border.all(
            color: accent
                ? palette.primary.withValues(alpha: 0.4)
                : palette.border,
            width: 1.0,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: palette.primary,
          collapsedIconColor: palette.muted,
          leading: Icon(icon,
              size: 18,
              color: accent ? palette.primary : palette.muted),
          title: Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              color: accent ? palette.primary : palette.text,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

/// Splita o coach rationale por seções `## ` e renderiza cada uma como
/// um ExpansionTile separado. Primeira seção começa aberta.
class _RationaleAccordion extends StatelessWidget {
  final Plan plan;
  const _RationaleAccordion({required this.plan});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final rationale = plan.coachRationale?.trim();
    if (rationale == null || rationale.isEmpty) {
      return _CollapsibleSection(
        icon: Icons.psychology_outlined,
        title: 'RACIONAL DO COACH',
        initiallyExpanded: true,
        child: Text(
          'O coach está escrevendo a análise detalhada do seu plano. Volte em alguns minutos.',
          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
        ),
      );
    }
    // Split por `## ` (header de seção). Cada seção: title=heading, body=resto.
    final sections = <(String, String)>[];
    final pattern = RegExp(r'^##\s+', multiLine: true);
    final matches = pattern.allMatches(rationale).toList();
    if (matches.isEmpty) {
      sections.add(('Racional', rationale));
    } else {
      // Prefácio antes do primeiro ## (se houver)
      if (matches.first.start > 0) {
        final pre = rationale.substring(0, matches.first.start).trim();
        if (pre.isNotEmpty) sections.add(('Resumo', pre));
      }
      for (var i = 0; i < matches.length; i++) {
        final start = matches[i].end;
        final endLine = rationale.indexOf('\n', start);
        final title = (endLine < 0
                ? rationale.substring(start)
                : rationale.substring(start, endLine))
            .trim();
        final bodyStart = endLine < 0 ? start : endLine + 1;
        final bodyEnd =
            (i + 1 < matches.length) ? matches[i + 1].start : rationale.length;
        final body = rationale.substring(bodyStart, bodyEnd).trim();
        if (title.isNotEmpty) sections.add((title, body));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'RACIONAL DO COACH',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < sections.length; i++) ...[
          _CollapsibleSection(
            icon: Icons.chevron_right,
            title: sections[i].$1.toUpperCase(),
            initiallyExpanded: i == 0,
            child: _MarkdownText(sections[i].$2),
          ),
          if (i < sections.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _RevisionsSection extends StatelessWidget {
  final List<PlanRevision> revisions;
  const _RevisionsSection({required this.revisions});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return _CollapsibleSection(
      icon: Icons.history,
      title: 'HISTÓRICO DE REVISÕES (${revisions.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in revisions) ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border.all(color: palette.border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEMANA ${r.weekNumber} · ${_shortDate(r.revisedAt)} · ${r.trigger}',
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.muted,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.summary,
                    style: TextStyle(color: palette.text, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
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

class _MesocycleCard extends StatelessWidget {
  final String text;
  const _MesocycleCard({required this.text});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.05),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text('ESTRATÉGIA DO MESOCICLO',
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.primary, fontSize: 11, letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(color: palette.text, fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}

// _CoachRationaleCard removido — substituído por _RationaleAccordion (acima)
// que renderiza cada seção ## do rationale como ExpansionTile colapsável.

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

int? _computeAge(String? birthDate) {
  if (birthDate == null || birthDate.isEmpty) return null;
  final d = DateTime.tryParse(birthDate);
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age > 0 && age < 120 ? age : null;
}

class _ProfileSummary extends StatelessWidget {
  final UserProfile? profile;
  const _ProfileSummary({this.profile});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    final age = _computeAge(p.birthDate);
    final genderLabel = switch (p.gender) {
      'male' => 'masculino',
      'female' => 'feminino',
      'other' => 'outro',
      _ => null,
    };
    final items = <(String, String)>[
      ('Nível', p.level),
      ('Objetivo', p.goal),
      ('Frequência', '${p.frequency}x/semana'),
      if (genderLabel != null) ('Gênero', genderLabel),
      if (age != null) ('Idade', '$age anos'),
      if (p.runPeriod != null) ('Período', p.runPeriod!),
      if (p.weight != null && p.weight!.isNotEmpty) ('Peso', p.weight!),
      if (p.height != null && p.height!.isNotEmpty) ('Altura', p.height!),
      if (p.restingBpm != null) ('FC repouso', '${p.restingBpm} bpm'),
      if (p.maxBpm != null) ('FC máx', '${p.maxBpm} bpm'),
      if ((p.medicalConditions ?? []).isNotEmpty)
        ('Condições', (p.medicalConditions ?? []).join(', '))
      else
        ('Condições', 'nenhuma informada'),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.calendar_view_week_outlined,
                  size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'PLANO SEMANA A SEMANA',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < plan.weeks.length; i++) ...[
          _WeekTile(week: plan.weeks[i], initiallyExpanded: i == 0, dayNames: _dayNames),
          if (i < plan.weeks.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  final PlanWeek week;
  final bool initiallyExpanded;
  final List<String> dayNames;
  const _WeekTile({
    required this.week,
    required this.initiallyExpanded,
    required this.dayNames,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final wKm = week.sessions.fold<double>(0, (s, x) => s + x.distanceKm);
    final sorted = [...week.sessions]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final restTipsByDay = {for (final t in week.restDayTips) t.dayOfWeek: t};
    final sessionDays = sorted.map((s) => s.dayOfWeek).toSet();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 1.0),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: palette.primary,
          collapsedIconColor: palette.muted,
          title: Row(
            children: [
              Text(
                'SEMANA ${week.weekNumber}',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.text,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${week.sessions.length} sess · ${wKm.toStringAsFixed(0)}km',
                style: GoogleFonts.jetBrainsMono(
                  color: palette.primary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          children: [
            if (week.narrative != null && week.narrative!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  week.narrative!.trim(),
                  style: TextStyle(
                    color: palette.text.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            // Renderiza TODOS os 7 dias da semana: sessões + rest tips +
            // dias sem nenhum dos dois (mostrados como "Descanso").
            for (var d = 1; d <= 7; d++) ...[
              if (sessionDays.contains(d))
                _SessionRow(
                  session: sorted.firstWhere((s) => s.dayOfWeek == d),
                  dayLabel: dayNames[d],
                )
              else if (restTipsByDay.containsKey(d))
                _RestDayRow(tip: restTipsByDay[d]!, dayLabel: dayNames[d])
              else
                _PlainRestRow(dayLabel: dayNames[d]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final PlanSession session;
  final String dayLabel;
  const _SessionRow({required this.session, required this.dayLabel});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final hasDetails = session.durationMin != null ||
        session.hydrationLiters != null ||
        (session.nutritionPre?.isNotEmpty ?? false) ||
        (session.nutritionPost?.isNotEmpty ?? false) ||
        session.notes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: hasDetails
          ? Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                iconColor: palette.primary,
                collapsedIconColor: palette.muted,
                title: _SessionHeader(session: session, dayLabel: dayLabel),
                children: [_SessionDetails(session: session)],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(10),
              child: _SessionHeader(session: session, dayLabel: dayLabel),
            ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final PlanSession session;
  final String dayLabel;
  const _SessionHeader({required this.session, required this.dayLabel});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final paceStr =
        session.targetPace != null ? ' · ${session.targetPace}/km' : '';
    final durStr = session.durationMin != null
        ? ' · ~${session.durationMin!.round()}min'
        : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            dayLabel,
            style: GoogleFonts.jetBrainsMono(
              color: palette.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${session.type} · ${session.distanceKm.toStringAsFixed(1)}km$paceStr$durStr',
            style: TextStyle(
              color: palette.text,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionDetails extends StatelessWidget {
  final PlanSession session;
  const _SessionDetails({required this.session});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final rows = <Widget>[];
    if (session.hydrationLiters != null) {
      rows.add(_DetailLine(
        icon: Icons.water_drop_outlined,
        label: 'HIDRATAÇÃO',
        value: '${session.hydrationLiters!.toStringAsFixed(1)}L no dia',
      ));
    }
    if ((session.nutritionPre ?? '').isNotEmpty) {
      rows.add(_DetailLine(
        icon: Icons.restaurant_outlined,
        label: 'PRÉ',
        value: session.nutritionPre!,
      ));
    }
    if ((session.nutritionPost ?? '').isNotEmpty) {
      rows.add(_DetailLine(
        icon: Icons.fastfood_outlined,
        label: 'PÓS',
        value: session.nutritionPost!,
      ));
    }
    if (session.notes.isNotEmpty) {
      rows.add(_DetailLine(
        icon: Icons.notes_outlined,
        label: 'NOTAS',
        value: session.notes,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: palette.muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: palette.text, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestDayRow extends StatelessWidget {
  final PlanRestDayTip tip;
  final String dayLabel;
  const _RestDayRow({required this.tip, required this.dayLabel});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  dayLabel,
                  style: GoogleFonts.jetBrainsMono(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  tip.focus ?? 'Descanso ativo',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ),
            ],
          ),
          if (tip.hydrationLiters != null || (tip.nutrition ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tip.hydrationLiters != null)
                    Text(
                      '${tip.hydrationLiters!.toStringAsFixed(1)}L de hidratação',
                      style: TextStyle(color: palette.text, fontSize: 10.5),
                    ),
                  if ((tip.nutrition ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tip.nutrition!,
                        style: TextStyle(color: palette.text, fontSize: 10.5, height: 1.4),
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

class _PlainRestRow extends StatelessWidget {
  final String dayLabel;
  const _PlainRestRow({required this.dayLabel});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              dayLabel,
              style: GoogleFonts.jetBrainsMono(
                color: palette.muted,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            'Descanso',
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
