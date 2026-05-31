import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Wizard nova de objetivo: 3 telas sequenciais (kind → subgoal/distance).
/// Substitui o PlanStepGoalV2 monolítico de 5 opções.

enum PlanGoalKind {
  flow('flow', 'TREINAR PRA FORMA', 'Sem prova, foco em consistência e progresso contínuo.'),
  race('race', 'ATINGIR UMA META', 'Distância (5/10/21/42K) ou bater um pace alvo.');

  final String backendValue;
  final String label;
  final String description;
  const PlanGoalKind(this.backendValue, this.label, this.description);
}

enum PlanFlowSubgoal {
  start('start', 'INICIAR', 'Nunca correu (ou voltando do zero). Walk-run, foco no hábito.'),
  improve('improve', 'MELHORAR PERFORMANCE', 'Já tem base. Quero qualidade pra romper plateau.'),
  injuryReturn('injury_return', 'VOLTA DE LESÃO', 'Já tive liberação médica. Conservador, sem qualidade no início.'),
  postpartum('postpartum', 'PÓS-PARTO', 'Retorno gradual com cuidado pra hidratação e sono.');

  final String backendValue;
  final String label;
  final String description;
  const PlanFlowSubgoal(this.backendValue, this.label, this.description);
}

enum PlanRaceMode {
  complete('complete', 'COMPLETAR', 'Cruzar a linha de chegada. Sem cobrança de tempo.'),
  improvePace('improve_pace', 'MELHORAR PACE', 'Tenho um tempo/pace alvo pra essa distância.');

  final String backendValue;
  final String label;
  final String description;
  const PlanRaceMode(this.backendValue, this.label, this.description);
}

/// Tela 1 do novo flow de objetivo: FLOW vs RACE.
class StepGoalKind extends StatelessWidget {
  final PlanGoalKind? selected;
  final ValueChanged<PlanGoalKind> onSelect;
  const StepGoalKind({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// SEU OBJETIVO'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'O que você quer agora?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'Treinar pra manter forma ou correr atrás de uma meta específica. '
              'Em qualquer caminho, o coach faz checkpoint semanal e ajusta as 2 próximas semanas.',
        ),
        const SizedBox(height: 22),
        for (final k in PlanGoalKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BigChoiceCard(
              label: k.label,
              description: k.description,
              selected: selected == k,
              onTap: () => onSelect(k),
            ),
          ),
      ],
    );
  }
}

/// Tela 2A (se FLOW): qual sub-meta?
class StepFlowSubgoal extends StatelessWidget {
  final PlanFlowSubgoal? selected;
  final ValueChanged<PlanFlowSubgoal> onSelect;
  const StepFlowSubgoal({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// FLOW'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Qual seu contexto?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'Lesão e pós-parto usam o que você marcou no passo de saúde pra calibrar — '
              'se não marcou nada, complete depois pelo Perfil pra o coach ajustar.',
        ),
        const SizedBox(height: 22),
        for (final s in PlanFlowSubgoal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BigChoiceCard(
              label: s.label,
              description: s.description,
              selected: selected == s,
              onTap: () => onSelect(s),
            ),
          ),
      ],
    );
  }
}

/// Tela 2B (se RACE): distância alvo + complete/improve_pace.
class StepRaceDistance extends StatelessWidget {
  final int? selectedDistance;
  final PlanRaceMode? selectedMode;
  /// Nível do atleta (iniciante/intermediario/avancado) — usado pra
  /// calcular cap volume/sessão e bloquear distâncias inviáveis.
  final String? level;
  /// Sub-categorização do iniciante (nunca_corri/esporadico/iniciante_freq).
  /// Usado pra bloquear distâncias longas pra subníveis sem base.
  final String? levelHint;
  /// Frequência já declarada no step anterior.
  final int? frequency;
  final ValueChanged<int> onSelectDistance;
  final ValueChanged<PlanRaceMode> onSelectMode;

  const StepRaceDistance({
    super.key,
    required this.selectedDistance,
    required this.selectedMode,
    required this.level,
    required this.levelHint,
    required this.frequency,
    required this.onSelectDistance,
    required this.onSelectMode,
  });

  static const _distances = [5, 10, 21, 42];

  /// Calcula motivo de bloqueio pra essa distância dadas as escolhas atuais.
  /// Retorna null quando a distância está OK.
  ///
  /// Regras (espelham server `plan-windows.constants.ts`):
  ///  0. Bypass: improve_pace + (avancado=qualquer / intermediario=5K|10K)
  ///     libera tudo (qualquer freq).
  ///  1. Sentinel BLOCKED_BY_LEVEL na matriz = combinação proibida (42K
  ///     pra iniciante; 21K/42K pra nunca_corri/esporadico; 42K pra
  ///     iniciante_freq).
  ///  2. Freq mínima por (subnível × distância) via getMinFreqFor.
  ///  3. Cap volume/sessão (peak / freq vs MAX_KM_PER_SESSION[level]).
  String? _disabledReason(int distanceKm) {
    final lvl = level;
    if (lvl == null) return null;

    // 0. Improve_pace bypass — pula 1/2/3.
    final isBypassed = selectedMode == PlanRaceMode.improvePace &&
        AdmissibilityConstants.hasImprovePaceBypass(lvl, distanceKm);
    if (isBypassed) return null;

    // 1+2. Matriz por subnível. Sentinel BLOCKED_BY_LEVEL = block por nível.
    final minFreq = AdmissibilityConstants.minFreqFor(
      lvl, distanceKm, levelHint: levelHint,
    );
    if (minFreq >= AdmissibilityConstants.blockedByLevel) {
      if (distanceKm == 42) {
        return 'Maratona não é pra quem está começando. Precisa de base de '
            'intermediário ou avançado. Comece com 10K ou 21K como Fase 1.';
      }
      if (distanceKm == 21) {
        if (levelHint == 'nunca_corri') {
          return 'Meia maratona precisa de uma base — começar do zero pede '
              '5K ou 10K como Fase 1.';
        }
        if (levelHint == 'esporadico') {
          return 'Meia maratona precisa de uma base — corridas esporádicas '
              'pedem 5K ou 10K como Fase 1.';
        }
      }
      return 'Essa distância não está liberada pra você. Comece com uma '
          'distância menor como Fase 1.';
    }
    if (frequency != null && frequency! < minFreq) {
      return 'Pra ${distanceKm}K nesse perfil, mínimo $minFreq treinos/sem '
          '(você tem $frequency).';
    }
    // 3. Cap volume/sessão
    final peak = AdmissibilityConstants.peakWeeklyKm[distanceKm] ?? 0;
    if (peak > 0 && frequency != null && frequency! > 0) {
      final cap = AdmissibilityConstants.maxKmPerSession[lvl] ?? 32;
      final projected = peak / frequency!;
      if (projected > cap) {
        final needFreq = (peak / cap).ceil();
        return 'Com $frequency treinos/sem cada sessão pra ${distanceKm}K ficaria '
            '~${projected.toStringAsFixed(0)}km — acima do cap ${cap}km pro $lvl. '
            'Mínimo $needFreq treinos/sem.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// META DE PROVA'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Qual distância?'),
        const SizedBox(height: 22),
        // Grid 2x2 de distâncias
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in _distances)
              SizedBox(
                width: (MediaQuery.of(context).size.width - 24 * 2 - 10) / 2,
                child: _DistanceCard(
                  km: d,
                  selected: selectedDistance == d,
                  disabledReason: _disabledReason(d),
                  onTap: () {
                    final reason = _disabledReason(d);
                    if (reason != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(reason),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ));
                      return;
                    }
                    onSelectDistance(d);
                  },
                ),
              ),
          ],
        ),
        // "Como quer abordar" só faz sentido pra quem já corre com algum
        // tipo de referência de pace. Quem nunca correu (levelHint=
        // 'nunca_corri') só pode escolher COMPLETE — sem pace pra
        // melhorar. Parent auto-seta _raceMode=complete no onSelectDistance.
        if (levelHint != 'nunca_corri') ...[
          const SizedBox(height: 26),
          Text(
            'COMO QUER ABORDAR?',
            style: context.runninType.labelMd.copyWith(
              color: palette.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          for (final m in PlanRaceMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BigChoiceCard(
                label: m.label,
                description: m.description,
                selected: selectedMode == m,
                onTap: () => onSelectMode(m),
                compact: true,
              ),
            ),
        ],
      ],
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final int km;
  final bool selected;
  final String? disabledReason;
  final VoidCallback onTap;
  const _DistanceCard({
    required this.km,
    required this.selected,
    required this.disabledReason,
    required this.onTap,
  });

  String get _label {
    switch (km) {
      case 5:
        return '5K';
      case 10:
        return '10K';
      case 21:
        return '21K\nMEIA';
      case 42:
        return '42K\nMARATONA';
      default:
        return '${km}K';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final disabled = disabledReason != null;
    final fg = disabled
        ? palette.muted
        : (selected ? palette.primary : palette.text);
    final bg = disabled
        ? palette.surface.withValues(alpha: 0.4)
        : (selected ? palette.primary.withValues(alpha: 0.12) : palette.surface);
    final border = disabled
        ? palette.border.withValues(alpha: 0.4)
        : (selected ? palette.primary : palette.border);
    return Tooltip(
      message: disabledReason ?? '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1.041),
          ),
          // Stack pra cadeado em overlay no canto, com Text centralizado
          // em FittedBox pra evitar overflow horizontal em labels longas
          // ("42K\nMARATONA").
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _label,
                    textAlign: TextAlign.center,
                    style: context.runninType.labelMd.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              if (disabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.lock_outline, size: 14, color: palette.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigChoiceCard extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _BigChoiceCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 12 : 16),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.runninType.labelMd.copyWith(
                color: selected ? palette.primary : palette.text,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: context.runninType.bodySm.copyWith(
                color: palette.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
