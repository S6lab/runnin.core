import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Steps que só aparecem quando goalKind=race:
///  - StepRaceTargetPace (só se raceMode=improve_pace)
///  - StepRaceWindow (sempre — 3 opções agressivo/factível/seguro)
///  - StepRaceDate (sempre — data específica da prova/alvo)
///
/// Os limites das janelas + ceiling de pace são duplicados do server
/// (`plan-windows.constants.ts`). Manter em sync ao mudar a tabela lá.

/// Janelas em semanas por (distância × nível). null = REDIRECT (server
/// bloqueia, FE não mostra essa opção). MIRROR de server RACE_WINDOWS.
class RaceWindowRow {
  final int? aggressive;
  final int? feasible;
  final int safe;
  const RaceWindowRow(this.aggressive, this.feasible, this.safe);
}

class RaceWindowsTable {
  // [distance][level] = { agg, fea, safe }
  static const _table = <int, Map<String, RaceWindowRow>>{
    5: {
      'iniciante':     RaceWindowRow(8, 10, 12),
      'intermediario': RaceWindowRow(6, 8, 10),
      'avancado':      RaceWindowRow(6, 6, 8),
    },
    10: {
      'iniciante':     RaceWindowRow(10, 12, 14),
      'intermediario': RaceWindowRow(8, 10, 12),
      'avancado':      RaceWindowRow(6, 8, 10),
    },
    21: {
      'iniciante':     RaceWindowRow(null, 16, 20),
      'intermediario': RaceWindowRow(12, 14, 18),
      'avancado':      RaceWindowRow(10, 12, 14),
    },
    42: {
      'iniciante':     RaceWindowRow(null, null, 26),
      'intermediario': RaceWindowRow(16, 18, 22),
      'avancado':      RaceWindowRow(14, 16, 20),
    },
  };

  static RaceWindowRow? lookup(int distanceKm, String level) =>
      _table[distanceKm]?[level];
}

/// Ceiling % de ganho de pace por nível em 12 sem (escala linear por weeks/12,
/// cap 0.5x a 1.5x). MIRROR de PACE_IMPROVEMENT_CEILING_PCT.
double maxPaceImprovementPct(String level, int weeksCount) {
  final base = switch (level) {
    'iniciante' => 8.0,
    'intermediario' => 5.0,
    'avancado' => 3.0,
    _ => 5.0,
  };
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

// ─── Tela: janela (agressivo/factível/seguro) ───────────────────────────────

class StepRaceWindow extends StatelessWidget {
  final int raceDistanceKm;
  final String level;
  /// Refinamento do iniciante (nunca_corri|esporadico|iniciante_freq).
  /// Define restrições estáticas de janela via getAllowedWindows.
  final String? levelHint;
  /// 'complete' | 'improve_pace' | null. Quando improve_pace + (level,
  /// distance) elegível, libera todas as janelas (bypass total).
  final String? raceMode;
  final DateTime startDate;
  /// Modo escolhido: 'aggressive' | 'feasible' | 'safe'. null = ainda não escolheu.
  final String? selectedMode;
  /// Idade calculada (do birthDate do profile). null = sem dado → sem restrição.
  final int? userAge;
  /// Condições médicas marcadas. Usadas pra desabilitar cards que violam.
  final List<String> medicalConditions;
  /// Frequência escolhida. null = ainda não passou pelo step de dias.
  /// Usada pra calcular projectedKmPerSession e desabilitar cards
  /// onde o volume estouraria o cap.
  final int? frequency;
  /// Volume semanal atual reportado em step_currentCapacity (km/sem).
  /// null = não reportou (ex: nunca_corri) → usa rampBaseFloorKm como base.
  /// Mirror do server `validate-volume-for-goal.ts` (max(floor, reported)).
  final double? currentWeeklyKm;
  final ValueChanged<String> onSelect;

  const StepRaceWindow({
    super.key,
    required this.raceDistanceKm,
    required this.level,
    required this.levelHint,
    required this.raceMode,
    required this.startDate,
    required this.selectedMode,
    required this.userAge,
    required this.medicalConditions,
    required this.frequency,
    required this.currentWeeklyKm,
    required this.onSelect,
  });

  String _projectedEndDate(int weeks) {
    final end = startDate.add(Duration(days: weeks * 7 - 1));
    return '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
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

    // 0. Bypass de improve_pace pra (level × distance) elegíveis. Libera
    //    todos os cards sem restrição (atleta toma decisão).
    final isImprovePaceBypassed = raceMode == 'improve_pace' &&
        AdmissibilityConstants.hasImprovePaceBypass(level, raceDistanceKm);

    String? reasonFor(String mode, int weeks) {
      if (isImprovePaceBypassed) return null;
      // 0.5 Window restriction por (subnível × distância × freq).
      //     Estática (nunca/esporadico + 10K → só safe) OU dinâmica
      //     (intermediario + 21K + freq=3 → só safe).
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
      // 1. Age cap
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
      // 2. Medical cap
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
      // 3. Volume cap (ramping). Base = max(floor, currentWeeklyKm reportado).
      //    Sem isso, intermediário (que já corre 25km/sem) é tratado como
      //    iniciante absoluto e nem 21K cabe — bug que travava as 3 janelas.
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
      // 4. Frequency cap (km/sessão)
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

    final cards = <_WindowOption>[
      if (row.aggressive != null)
        _WindowOption('aggressive', 'AGRESSIVO', row.aggressive!, 'Janela enxuta. Requer base sólida e regularidade.',
            disabledReason: reasonFor('aggressive', row.aggressive!)),
      if (row.feasible != null)
        _WindowOption('feasible', 'FACTÍVEL', row.feasible!, 'Equilíbrio entre progressão e folga. Recomendado.',
            disabledReason: reasonFor('feasible', row.feasible!)),
      _WindowOption('safe', 'SEGURO', row.safe, 'Mais semanas pra construir base com calma.',
          disabledReason: reasonFor('safe', row.safe)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// JANELA DE PREPARAÇÃO'),
        const SizedBox(height: 14),
        FigmaAssessmentHeading(text: 'Quanto tempo você tem?'),
        const SizedBox(height: 10),
        FigmaAssessmentDescription(
          text: 'Tempo total que o plano leva. Se teu desempenho permitir, '
              'o coach pode antecipar a meta via checkpoint semanal.',
        ),
        const SizedBox(height: 22),
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WindowCard(
              option: c,
              isSelected: selectedMode == c.mode,
              palette: palette,
              type: type,
              projectedEndDate: _projectedEndDate(c.weeks),
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
                onSelect(c.mode);
              },
            ),
          ),
      ],
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
                    : 'chega ~ $projectedEndDate',
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

// ─── Tela: data alvo da prova ───────────────────────────────────────────────

class StepRaceDate extends StatelessWidget {
  final DateTime startDate;
  final int defaultWeeks;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;

  const StepRaceDate({
    super.key,
    required this.startDate,
    required this.defaultWeeks,
    required this.selectedDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final defaultEnd = startDate.add(Duration(days: defaultWeeks * 7 - 1));
    final picked = selectedDate ?? defaultEnd;
    final weeksFromStart = ((picked.difference(startDate).inDays + 1) / 7).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// DATA DA META'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Quando vai correr?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'Data específica da prova ou do dia que vai bater a meta. '
              'Coach periodiza pra chegar lá.',
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap: () async {
            final result = await showDatePicker(
              context: context,
              initialDate: picked,
              firstDate: startDate,
              lastDate: startDate.add(const Duration(days: 365)),
            );
            if (result != null) onSelect(result);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.primary, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: palette.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${picked.day.toString().padLeft(2, '0')} / '
                        '${picked.month.toString().padLeft(2, '0')} / '
                        '${picked.year}',
                        style: type.dataMd.copyWith(color: palette.primary, fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$weeksFromStart semanas de preparação',
                        style: type.bodySm.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'A data fica fixa. Se o teu desempenho permitir, o coach pode antecipar '
          'a meta — o objetivo virá antes via checkpoint semanal.',
          style: type.bodyXs.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
