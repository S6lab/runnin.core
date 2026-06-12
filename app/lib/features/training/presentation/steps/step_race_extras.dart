import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Steps que só aparecem quando goalKind=race:
///  - StepRaceTargetPace (só se raceMode=improve_pace)
///  - StepRaceTiming (sempre — início + janela + dia exato, numa tela)
///
/// As regras vêm de `AdmissibilityConstants` (config remoto do server com
/// fallback hardcoded) — não há mais tabela espelho local neste arquivo.

/// Delegate fino pra `AdmissibilityConstants.raceWindows` (mantém o call
/// site `RaceWindowsTable.lookup` usado pelo wizard).
class RaceWindowsTable {
  static RaceWindowRow? lookup(int distanceKm, String level) =>
      AdmissibilityConstants.raceWindows[distanceKm]?[level];
}

/// Ceiling % de ganho de pace por nível em 12 sem (escala linear por weeks/12,
/// cap 0.5x a 1.5x). Fonte: AdmissibilityConstants (remoto com fallback).
double maxPaceImprovementPct(String level, int weeksCount) {
  final base = AdmissibilityConstants.paceImprovementCeilingPct[level] ?? 5.0;
  final scale = (weeksCount / 12.0).clamp(0.5, 1.5);
  return base * scale;
}

// ─── Tela: pace alvo ─────────────────────────────────────────────────────────

class StepRaceTargetPace extends StatefulWidget {
  /// Pace atual do user (M:SS/km), capturado em step_current_capacity.
  /// Sem isso, a tela mostra um aviso pedindo pra voltar e preencher.
  final String? currentPaceMinKm;
  /// Pace alvo escolhido (M:SS/km). null = ainda não escolheu.
  final String? targetPace;
  final String level;
  final int weeksCount;
  final ValueChanged<String> onSelect;

  const StepRaceTargetPace({
    super.key,
    required this.currentPaceMinKm,
    required this.targetPace,
    required this.level,
    required this.weeksCount,
    required this.onSelect,
  });

  @override
  State<StepRaceTargetPace> createState() => _StepRaceTargetPaceState();
}

class _StepRaceTargetPaceState extends State<StepRaceTargetPace> {
  static int? _parsePace(String p) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(p);
    if (m == null) return null;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  static String _fmtPace(int secPerKm) {
    final m = secPerKm ~/ 60;
    final s = secPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    if (widget.currentPaceMinKm == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const FigmaAssessmentLabel(text: '// PACE ALVO'),
          const SizedBox(height: 14),
          const FigmaAssessmentHeading(text: 'Volta um passo'),
          const SizedBox(height: 10),
          FigmaAssessmentDescription(
            text: 'Pra propor um pace alvo realista, preciso saber o que você '
                'corre hoje. Volta no passo "capacidade atual" e marca "JÁ CORRO" '
                'com uma corrida recente.',
          ),
        ],
      );
    }

    final currentSec = _parsePace(widget.currentPaceMinKm!);
    if (currentSec == null) {
      return Text('Pace atual inválido: ${widget.currentPaceMinKm}', style: type.bodyMd);
    }
    final maxPct = maxPaceImprovementPct(widget.level, widget.weeksCount);
    final fastestSec = (currentSec * (1 - maxPct / 100)).round();
    final slowestSec = currentSec - 5; // mínimo de melhora: 5s/km
    final currentLabel = _fmtPace(currentSec);
    final fastestLabel = _fmtPace(fastestSec);

    // Gera 8 opções entre fastestSec e slowestSec (passo derivado)
    final spread = (slowestSec - fastestSec).abs();
    final stepSize = (spread / 7).round().clamp(2, 20);
    final options = <int>[];
    for (var s = fastestSec; s <= slowestSec; s += stepSize) {
      options.add(s);
    }

    final selectedSec = widget.targetPace != null ? _parsePace(widget.targetPace!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// PACE ALVO'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Qual ritmo você quer atingir?'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PACE ATUAL', style: type.labelMd.copyWith(color: palette.muted, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text('$currentLabel/km', style: type.dataMd),
                ],
              )),
              Container(width: 1, height: 40, color: palette.border),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAX MELHORA', style: type.labelMd.copyWith(color: palette.primary, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text('$fastestLabel/km',
                       style: type.dataMd.copyWith(color: palette.primary)),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Limite por nível (${widget.level}) em ${widget.weeksCount}sem: ~${maxPct.toStringAsFixed(0)}% de ganho.',
          style: type.bodyXs.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 22),
        Text(
          'ESCOLHE O ALVO',
          style: type.labelMd.copyWith(color: palette.muted, letterSpacing: 1.2, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sec in options)
              _PaceChip(
                label: '${_fmtPace(sec)}/km',
                selected: selectedSec == sec,
                onTap: () => widget.onSelect(_fmtPace(sec)),
              ),
          ],
        ),
      ],
    );
  }
}

class _PaceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.text,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── Tela: timing da prova (início + janela + dia exato) ────────────────────

/// Funde os antigos StepRaceWindow + StepRaceDate + startDate (pra race) em
/// 3 partes progressivas. A raceDate vira ESTADO DERIVADO de
/// (início, janela, dia) — o picker livre morreu, então
/// `ceil((race−start)/7) == weeks` por construção e mudar o início
/// re-deriva a data sem estado stale.
class StepRaceTiming extends StatelessWidget {
  // Parte 1 — início
  final String startChoice; // 'today' | 'tomorrow' | 'next_monday' | 'custom'
  final DateTime customStartDate;
  final void Function(String choice, DateTime date) onStartSelect;
  /// Início resolvido (meia-noite local) — fonte das projeções de data.
  final DateTime startDate;

  /// Dias de treino marcados (1=seg..7=dom). Quando o início escolhido cai
  /// fora deles, mostramos o aviso "1º treino cai em X" + ação rápida.
  final Set<int> availableDays;
  final ValueChanged<int> onAddTrainingDay;

  // Parte 2 — janela
  final int raceDistanceKm;
  final String level;
  final String? levelHint;
  final String? raceMode;
  final String? selectedMode;
  final int? userAge;
  final List<String> medicalConditions;
  final int? frequency;
  final double? currentWeeklyKm;
  final ValueChanged<String> onWindowSelect;

  // Parte 3 — dia exato dentro da semana final
  final int raceDayOfWeek; // 1=seg..7=dom
  final ValueChanged<int> onRaceDaySelect;

  // Escape hatch — prova com data já marcada
  final DateTime? explicitRaceDate;
  final ValueChanged<DateTime?> onExplicitRaceDateChange;

  /// Data derivada final (parent computa; inclui o caso explícito).
  final DateTime? derivedRaceDate;

  const StepRaceTiming({
    super.key,
    required this.startChoice,
    required this.customStartDate,
    required this.onStartSelect,
    required this.startDate,
    required this.availableDays,
    required this.onAddTrainingDay,
    required this.raceDistanceKm,
    required this.level,
    required this.levelHint,
    required this.raceMode,
    required this.selectedMode,
    required this.userAge,
    required this.medicalConditions,
    required this.frequency,
    required this.currentWeeklyKm,
    required this.onWindowSelect,
    required this.raceDayOfWeek,
    required this.onRaceDaySelect,
    required this.explicitRaceDate,
    required this.onExplicitRaceDateChange,
    required this.derivedRaceDate,
  });

  static DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _nextMonday() {
    final t = _todayMidnight();
    final daysAhead = t.weekday == 1 ? 7 : (8 - t.weekday);
    return t.add(Duration(days: daysAhead));
  }

  static const _dowShort = ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const _dowLong = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

  String _ddmm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _ddmmyyyy(DateTime d) => '${_ddmm(d)}/${d.year}';

  int? _weeksForMode(String mode) {
    final row = RaceWindowsTable.lookup(raceDistanceKm, level);
    if (row == null) return null;
    return mode == 'aggressive'
        ? (row.aggressive ?? row.feasible ?? row.safe)
        : mode == 'feasible'
            ? (row.feasible ?? row.safe)
            : row.safe;
  }

  /// Primeiro dia da semana final do plano de W semanas: o intervalo de
  /// datas válidas pra W é `start + [(W−1)*7+1 .. W*7]` dias (espelho do
  /// `ceil` do server) — 7 dias consecutivos, um por dia-da-semana.
  DateTime _finalWeekFirstDay(int weeks) =>
      startDate.add(Duration(days: (weeks - 1) * 7 + 1));

  /// Menor janela permitida pro perfil (pra restringir o picker do escape
  /// hatch). Considera windowRestrictionByProfile/dinâmica via
  /// getAllowedWindows; age/medical são validados no submit.
  int? _minAllowedWeeks() {
    final row = RaceWindowsTable.lookup(raceDistanceKm, level);
    if (row == null) return null;
    final allowed = AdmissibilityConstants.getAllowedWindows(
          level, raceDistanceKm, frequency ?? 0, levelHint: levelHint,
        ) ??
        const ['aggressive', 'feasible', 'safe'];
    int? min;
    for (final mode in allowed) {
      final w = mode == 'aggressive'
          ? row.aggressive
          : mode == 'feasible'
              ? row.feasible
              : row.safe;
      if (w != null && (min == null || w < min)) min = w;
    }
    return min;
  }

  String? _windowLabelForWeeks(int weeks) {
    final row = RaceWindowsTable.lookup(raceDistanceKm, level);
    if (row == null) return null;
    if (weeks >= row.safe) return 'SEGURA';
    if (row.feasible != null && weeks >= row.feasible!) return 'FACTÍVEL';
    if (row.aggressive != null && weeks >= row.aggressive!) return 'AGRESSIVA';
    return null;
  }

  String? _disabledReasonFor(String mode, int weeks) {
    final isImprovePaceBypassed = raceMode == 'improve_pace' &&
        AdmissibilityConstants.hasImprovePaceBypass(level, raceDistanceKm);
    if (isImprovePaceBypassed) return null;
    // Window restriction por (subnível × distância × freq).
    if (frequency != null && frequency! > 0) {
      final allowed = AdmissibilityConstants.getAllowedWindows(
        level, raceDistanceKm, frequency!,
        levelHint: levelHint,
      );
      if (allowed != null && !allowed.contains(mode)) {
        final label = allowed.map((w) {
          if (w == 'safe') return 'SEGURA';
          if (w == 'feasible') return 'FACTÍVEL';
          return 'AGRESSIVA';
        }).join(' / ');
        return 'Pra ${raceDistanceKm}K nesse perfil, só janela $label.';
      }
    }
    // Age cap
    if (userAge != null) {
      if (userAge! >= AdmissibilityConstants.forceSafeMarathonAge && raceDistanceKm == 42 && mode != 'safe') {
        return 'Pelos seus $userAge anos pra maratona, só janela SEGURA.';
      }
      if (userAge! >= AdmissibilityConstants.forceFeasibleHalfAge && raceDistanceKm == 21 && mode == 'aggressive') {
        return 'Pelos seus $userAge anos pra meia, mínimo FACTÍVEL.';
      }
      if (userAge! >= AdmissibilityConstants.blockAggressiveAge && raceDistanceKm == 42 && mode == 'aggressive') {
        return 'Pelos seus $userAge anos pra maratona, mínimo FACTÍVEL.';
      }
    }
    // Medical cap
    final med = medicalConditions.where((c) => c.trim().isNotEmpty).toList();
    if (med.isNotEmpty && mode != 'safe') {
      if (med.length >= 3) {
        return 'Você marcou ${med.length} condições — só janela SEGURA.';
      }
      if (raceDistanceKm >= 21) {
        for (final c in med) {
          final norm = c.toLowerCase()
              .replaceAll(RegExp(r'[áàâã]'), 'a').replaceAll(RegExp(r'[éèê]'), 'e')
              .replaceAll(RegExp(r'[íì]'), 'i').replaceAll(RegExp(r'[óòôõ]'), 'o')
              .replaceAll(RegExp(r'[úù]'), 'u').replaceAll('ç', 'c');
          for (final kw in AdmissibilityConstants.seriousMedicalKeywords) {
            if (norm.contains(kw)) return 'Condição "$c" pede janela SEGURA.';
          }
        }
      }
    }
    // Volume cap (ramping). Base = max(floor, currentWeeklyKm reportado).
    final peak = AdmissibilityConstants.peakWeeklyKm[raceDistanceKm] ?? 0;
    if (peak > 0) {
      final reported = currentWeeklyKm ?? 0;
      final base = reported > AdmissibilityConstants.rampBaseFloorKm
          ? reported
          : AdmissibilityConstants.rampBaseFloorKm.toDouble();
      var ramped = base;
      for (var i = 0; i < weeks; i++) {
        ramped *= AdmissibilityConstants.weeklyRampRate;
      }
      if (ramped < peak) {
        return 'Saindo de ${base.toStringAsFixed(0)}km/sem, em $weeks sem ramp chega '
            'só ${ramped.toStringAsFixed(0)}km/sem — pico ${peak}km/sem não cabe.';
      }
    }
    // Frequency cap (km/sessão)
    if (frequency != null && peak > 0 && frequency! > 0) {
      final cap = AdmissibilityConstants.maxKmPerSession[level] ?? 32;
      final projected = peak / frequency!;
      if (projected > cap) {
        return 'Com ${frequency!} treinos/sem cada sessão fica ~${projected.toStringAsFixed(0)}km — '
            'acima do cap ${cap}km. Aumenta a freq antes.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final row = RaceWindowsTable.lookup(raceDistanceKm, level);
    if (row == null) {
      return Text('Combinação inválida: ${raceDistanceKm}K x $level',
          style: type.bodyMd.copyWith(color: palette.error));
    }

    final today = _todayMidnight();
    final tomorrow = today.add(const Duration(days: 1));
    final nextMonday = _nextMonday();

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: type.labelMd.copyWith(
              color: palette.muted, letterSpacing: 1.2, fontSize: 11,
            ),
          ),
        );

    final children = <Widget>[
      const SizedBox(height: 12),
      const FigmaAssessmentLabel(text: '// DATA DA META'),
      const SizedBox(height: 14),
      const FigmaAssessmentHeading(text: 'Vamos montar a data.'),
      const SizedBox(height: 10),
      const FigmaAssessmentDescription(
        text: 'Início + janela de preparo + dia exato. A data da prova fica '
            'fixa no plano — o coach periodiza pra chegar nela.',
      ),
      const SizedBox(height: 22),

      // ── Parte 1: início ──
      sectionLabel('1 · QUANDO VOCÊ COMEÇA'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TimingChip(
            label: 'HOJE',
            sub: _ddmm(today),
            selected: startChoice == 'today',
            onTap: () => onStartSelect('today', today),
          ),
          _TimingChip(
            label: 'AMANHÃ',
            sub: _ddmm(tomorrow),
            selected: startChoice == 'tomorrow',
            onTap: () => onStartSelect('tomorrow', tomorrow),
          ),
          _TimingChip(
            label: 'SEGUNDA',
            sub: _ddmm(nextMonday),
            selected: startChoice == 'next_monday',
            onTap: () => onStartSelect('next_monday', nextMonday),
          ),
          _TimingChip(
            label: 'OUTRA DATA',
            sub: startChoice == 'custom' ? _ddmm(customStartDate) : '…',
            selected: startChoice == 'custom',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startChoice == 'custom' ? customStartDate : today,
                firstDate: today,
                lastDate: today.add(const Duration(days: 60)),
              );
              if (picked != null) onStartSelect('custom', picked);
            },
          ),
        ],
      ),
      // Início fora dos dias de treino: o plano COMEÇA na data escolhida,
      // mas o 1º treino cai no próximo dia marcado — explicitar aqui mata
      // o "pedi HOJE e não tem treino hoje" (TF: quinta fora de seg/qua/
      // sex/sáb). Ação rápida adiciona o dia.
      if (availableDays.isNotEmpty && !availableDays.contains(startDate.weekday))
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: StartDayNotice(
            startDate: startDate,
            availableDays: availableDays,
            onAddTrainingDay: onAddTrainingDay,
          ),
        ),
      const SizedBox(height: 22),
    ];

    if (explicitRaceDate == null) {
      // ── Parte 2: janela ──
      children.add(sectionLabel('2 · QUANTO TEMPO DE PREPARO'));
      final cards = <_WindowOption>[
        if (row.aggressive != null)
          _WindowOption('aggressive', 'AGRESSIVO', row.aggressive!,
              'Janela enxuta. Requer base sólida e regularidade.',
              disabledReason: _disabledReasonFor('aggressive', row.aggressive!)),
        if (row.feasible != null)
          _WindowOption('feasible', 'FACTÍVEL', row.feasible!,
              'Equilíbrio entre progressão e folga. Recomendado.',
              disabledReason: _disabledReasonFor('feasible', row.feasible!)),
        _WindowOption('safe', 'SEGURO', row.safe,
            'Mais semanas pra construir base com calma.',
            disabledReason: _disabledReasonFor('safe', row.safe)),
      ];
      for (final c in cards) {
        final end = startDate.add(Duration(days: c.weeks * 7 - 1));
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _WindowCard(
            option: c,
            isSelected: selectedMode == c.mode,
            palette: palette,
            type: type,
            projectedEndDate: _ddmmyyyy(end),
            onTap: () {
              if (c.disabledReason != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(c.disabledReason!),
                  backgroundColor: palette.surface,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ));
                return;
              }
              onWindowSelect(c.mode);
            },
          ),
        ));
      }

      // ── Parte 3: dia exato (após escolher a janela) ──
      final weeks = selectedMode != null ? _weeksForMode(selectedMode!) : null;
      if (weeks != null) {
        final firstDay = _finalWeekFirstDay(weeks);
        final lastDay = firstDay.add(const Duration(days: 6));
        children
          ..add(const SizedBox(height: 12))
          ..add(sectionLabel('3 · QUE DIA EXATO?'))
          ..add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Semana da prova: ${_ddmm(firstDay)} — ${_ddmm(lastDay)}',
              style: type.bodySm.copyWith(color: palette.muted),
            ),
          ))
          ..add(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(builder: (context) {
                  final d = firstDay.add(Duration(days: i));
                  return _TimingChip(
                    label: _dowShort[d.weekday],
                    sub: _ddmm(d),
                    selected: raceDayOfWeek == d.weekday,
                    onTap: () => onRaceDaySelect(d.weekday),
                  );
                }),
            ],
          ));
      }
    } else {
      // ── Escape hatch ativo: prova com data marcada ──
      final picked = explicitRaceDate!;
      final days = picked.difference(startDate).inDays;
      final weeks = (days / 7).ceil();
      final windowLabel = _windowLabelForWeeks(weeks);
      children
        ..add(sectionLabel('2 · SUA PROVA'))
        ..add(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.12),
            border: Border.all(color: palette.primary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_dowLong[picked.weekday]} · ${_ddmmyyyy(picked)}',
                style: type.dataMd.copyWith(color: palette.primary, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                windowLabel != null
                    ? '$weeks semanas de preparo — janela $windowLabel'
                    : '$weeks semanas — abaixo do mínimo pro seu perfil',
                style: type.bodySm.copyWith(
                  color: windowLabel != null ? palette.muted : palette.warning,
                ),
              ),
            ],
          ),
        ))
        ..add(const SizedBox(height: 10))
        ..add(TextButton(
          onPressed: () => onExplicitRaceDateChange(null),
          child: const Text('USAR MODO GUIADO (JANELA + DIA)'),
        ));
    }

    // Resumo + escape hatch
    if (explicitRaceDate == null && derivedRaceDate != null) {
      final d = derivedRaceDate!;
      children
        ..add(const SizedBox(height: 8))
        ..add(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Text(
            'PROVA: ${_dowLong[d.weekday]} · ${_ddmmyyyy(d)}. '
            'A data fica fixa no plano.',
            style: type.bodySm.copyWith(color: palette.text, height: 1.4),
          ),
        ));
    }
    if (explicitRaceDate == null) {
      children
        ..add(const SizedBox(height: 8))
        ..add(TextButton(
          onPressed: () async {
            final minWeeks = _minAllowedWeeks() ?? row.safe;
            final firstDate = startDate.add(Duration(days: minWeeks * 7 - 6));
            final lastDate = startDate.add(const Duration(days: 365));
            final picked = await showDatePicker(
              context: context,
              initialDate: firstDate,
              firstDate: firstDate,
              lastDate: lastDate,
              helpText: 'DATA DA SUA PROVA',
            );
            if (picked != null) {
              onExplicitRaceDateChange(DateTime(picked.year, picked.month, picked.day));
            }
          },
          child: const Text('JÁ TENHO PROVA COM DATA MARCADA >'),
        ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Aviso "o início escolhido não é dia de treino" + ação rápida. Público
/// pra reuso no caminho FLOW (step de startDate do wizard).
class StartDayNotice extends StatelessWidget {
  final DateTime startDate;
  final Set<int> availableDays;
  final ValueChanged<int> onAddTrainingDay;

  const StartDayNotice({
    super.key,
    required this.startDate,
    required this.availableDays,
    required this.onAddTrainingDay,
  });

  static const _dowLong = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

  int? _nextTrainingDow() {
    if (availableDays.isEmpty) return null;
    for (var i = 1; i <= 7; i++) {
      final dow = ((startDate.weekday - 1 + i) % 7) + 1;
      if (availableDays.contains(dow)) return dow;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final startName = _dowLong[startDate.weekday];
    final next = _nextTrainingDow();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.08),
        border: Border.all(color: palette.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$startName não está nos seus dias de treino — o plano começa '
            'nessa data, mas o 1º treino cai ${next != null ? _comDia(next) : 'no próximo dia marcado'}.',
            style: type.bodySm.copyWith(color: palette.text, height: 1.4),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onAddTrainingDay(startDate.weekday),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('TREINAR ${startName.toUpperCase()} TAMBÉM'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_field
  static const _pre = ' ';
  String _comDia(int dow) {
    final name = _dowLong[dow];
    return (dow == 6 || dow == 7) ? 'no $name' : 'na $name';
  }
}

class _TimingChip extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _TimingChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(color: selected ? palette.primary : palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: type.labelMd.copyWith(
                color: selected ? palette.primary : palette.text,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: type.bodyXs.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowOption {
  final String mode;
  final String label;
  final int weeks;
  final String description;
  /// Quando != null, card aparece disabled e tap mostra snackbar.
  final String? disabledReason;
  const _WindowOption(this.mode, this.label, this.weeks, this.description, {this.disabledReason});
}

class _WindowCard extends StatelessWidget {
  final _WindowOption option;
  final bool isSelected;
  final RunninPalette palette;
  final RunninTypography type;
  final String projectedEndDate;
  final VoidCallback onTap;

  const _WindowCard({
    required this.option,
    required this.isSelected,
    required this.palette,
    required this.type,
    required this.projectedEndDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = option.disabledReason != null;
    final fg = disabled ? palette.muted : (isSelected ? palette.primary : palette.text);
    final border = disabled
        ? palette.border.withValues(alpha: 0.4)
        : (isSelected ? palette.primary : palette.border);
    final bg = disabled
        ? palette.surface.withValues(alpha: 0.4)
        : (isSelected ? palette.primary.withValues(alpha: 0.12) : palette.surface);
    return Tooltip(
      message: option.disabledReason ?? '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg, border: Border.all(color: border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: type.labelMd.copyWith(color: fg, letterSpacing: 1.2),
                    ),
                  ),
                  Text(
                    '${option.weeks} sem',
                    style: type.dataMd.copyWith(color: fg, fontSize: 18),
                  ),
                  if (disabled) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.lock_outline, size: 16, color: palette.muted),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                style: type.bodySm.copyWith(color: palette.muted, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                disabled
                    ? option.disabledReason!
                    : 'semana da prova termina ~ $projectedEndDate',
                style: type.bodyXs.copyWith(
                  color: disabled ? palette.warning : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
