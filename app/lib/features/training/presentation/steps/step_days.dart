import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Tela combinada "dias disponíveis × treinos/sem". Dias e frequência são
/// INDEPENDENTES: user marca quais dias está disponível (1=seg…7=dom) E
/// quantos treinos quer (freq ≤ qtd de dias marcados). Se freq < dias
/// marcados, a IA escolhe os melhores dias.
class PlanStepDays extends StatelessWidget {
  final Set<int> availableDays;
  final int frequency;
  /// Dia preferido pro long run (1=seg…7=dom). null = coach escolhe.
  final int? longRunDayOfWeek;
  /// Tempo máx disponível pro long run em min. null = sem cap.
  final int? longRunMaxMinutes;
  /// Distância alvo (5/10/21/42) quando RACE — usado pra inline warning
  /// de frequência mínima. null = FLOW ou ainda não escolheu.
  final int? raceDistanceKm;
  /// True quando goalKind == race. Esconde freq=1 nos chips (mínimo
  /// absoluto pra qualquer plano de prova é 2 treinos/sem — 1 sessão
  /// não periodiza). Combinações específicas (10K com 3, 42K com 4) são
  /// gateadas downstream no card de distância.
  final bool isRaceGoal;
  /// Nível do atleta — usado junto com raceDistanceKm pra projetar
  /// km/sessão e disparar warning quando volume/sessão estoura cap.
  final String? level;
  /// Refinamento do iniciante (nunca_corri|esporadico|iniciante_freq).
  /// Define qual linha da matriz MIN_FREQ_BY_PROFILE_DISTANCE usar.
  final String? levelHint;
  /// 'complete' | 'improve_pace' | null. Quando improve_pace + (level,
  /// distance) elegível, dispensa o warning de freq mínima (bypass).
  final String? raceMode;
  final ValueChanged<Set<int>> onDaysChange;
  final ValueChanged<int> onFreqChange;
  final ValueChanged<int?> onLongRunDayChange;
  final ValueChanged<int?> onLongRunMaxMinutesChange;

  const PlanStepDays({
    super.key,
    required this.availableDays,
    required this.frequency,
    required this.longRunDayOfWeek,
    required this.longRunMaxMinutes,
    required this.raceDistanceKm,
    required this.isRaceGoal,
    required this.level,
    required this.levelHint,
    required this.raceMode,
    required this.onDaysChange,
    required this.onFreqChange,
    required this.onLongRunDayChange,
    required this.onLongRunMaxMinutesChange,
  });

  static const _dayLabels = <String>['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final daysCount = availableDays.length;
    final freqClamped = frequency.clamp(1, 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// SUA ROTINA'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Quando você pode treinar?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Primeiro diz quantos treinos/sem dá pra fazer. Depois marca os '
              'dias da semana em que cabe — precisa marcar pelo menos a mesma '
              'quantidade de dias.',
        ),
        const SizedBox(height: 22),
        // 1. Frequência primeiro (decisão de carga).
        Text(
          'QUANTOS TREINOS POR SEMANA?',
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Race: chips começam em 2 (1x não periodiza plano de prova).
            // Flow: começam em 1.
            for (var n = (isRaceGoal ? 2 : 1); n <= 7; n++)
              _FreqChip(
                label: '$n',
                selected: freqClamped == n,
                enabled: true,
                onTap: () => onFreqChange(n),
              ),
          ],
        ),
        // Inline warning: se RACE escolhido + freq insuficiente pra
        // distância, alerta em amarelo antes de avançar (user evita
        // bater no bottom sheet no fim).
        if (raceDistanceKm != null) ..._buildFreqWarning(context, palette),
        const SizedBox(height: 22),
        // 2. Dias da semana. Mínimo de marcações = frequency.
        Text(
          'QUAIS DIAS DA SEMANA?',
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          daysCount >= frequency
              ? 'Marcou $daysCount dia${daysCount > 1 ? 's' : ''} — coach escolhe os $freqClamped melhores.'
              : 'Precisa marcar pelo menos $frequency dias (1 por treino).',
          style: context.runninType.bodyXs.copyWith(
            color: daysCount >= frequency ? palette.muted : palette.warning,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= 7; i++)
              _DayChip(
                label: _dayLabels[i - 1],
                selected: availableDays.contains(i),
                onTap: () {
                  final next = Set<int>.from(availableDays);
                  if (next.contains(i)) {
                    // Bloqueia uncheck que dropa contagem abaixo da freq
                    // escolhida — sem isso o coach não tem onde alocar
                    // todas as sessões.
                    if (next.length <= frequency) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Você pediu $frequency treinos/sem — precisa marcar pelo menos $frequency dias.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    next.remove(i);
                  } else {
                    next.add(i);
                  }
                  onDaysChange(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 28),
        // Dia preferido pro Long Run (opcional). Chip "AUTO" = coach decide.
        // Lista apenas os dias que o user marcou como disponíveis +
        // sábado/domingo como opção típica mesmo se não marcou (long run
        // pede mais tempo, geralmente fim de semana).
        Text(
          'DIA PREFERIDO PRO LONG RUN',
          style: context.runninType.labelMd.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'O treino mais longo da semana. Se não escolher, coach decide pelos dias disponíveis.',
          style: context.runninType.bodyXs.copyWith(color: palette.muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LongRunChip(
              label: 'AUTO',
              selected: longRunDayOfWeek == null,
              onTap: () => onLongRunDayChange(null),
            ),
            for (var i = 1; i <= 7; i++)
              if (availableDays.contains(i))
                _LongRunChip(
                  label: _dayLabels[i - 1],
                  selected: longRunDayOfWeek == i,
                  onTap: () => onLongRunDayChange(i),
                ),
          ],
        ),
        if (longRunDayOfWeek != null) ...[
          const SizedBox(height: 20),
          Text(
            'NESSE DIA, QUANTO TEMPO TENS PRA CORRER?',
            style: context.runninType.labelMd.copyWith(
              color: palette.muted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coach respeita esse teto — sem long run de 3h se você só tem 1h livre.',
            style: context.runninType.bodyXs.copyWith(color: palette.muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LongRunChip(
                label: '60min',
                selected: longRunMaxMinutes == 60,
                onTap: () => onLongRunMaxMinutesChange(60),
              ),
              _LongRunChip(
                label: '90min',
                selected: longRunMaxMinutes == 90,
                onTap: () => onLongRunMaxMinutesChange(90),
              ),
              _LongRunChip(
                label: '120min',
                selected: longRunMaxMinutes == 120,
                onTap: () => onLongRunMaxMinutesChange(120),
              ),
              _LongRunChip(
                label: '150min',
                selected: longRunMaxMinutes == 150,
                onTap: () => onLongRunMaxMinutesChange(150),
              ),
              _LongRunChip(
                label: '180min',
                selected: longRunMaxMinutes == 180,
                onTap: () => onLongRunMaxMinutesChange(180),
              ),
              _LongRunChip(
                label: 'SEM LIMITE',
                selected: longRunMaxMinutes == null,
                onTap: () => onLongRunMaxMinutesChange(null),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildFreqWarning(BuildContext context, RunninPalette palette) {
    final dist = raceDistanceKm;
    if (dist == null) return const [];
    final lvl = level ?? 'iniciante';

    // 0. improve_pace bypass: avancado=qualquer / intermediario=5K|10K.
    //    Sem warning de freq mínima nesses casos.
    final isBypassed = raceMode == 'improve_pace' &&
        AdmissibilityConstants.hasImprovePaceBypass(lvl, dist);

    final cap = AdmissibilityConstants.maxKmPerSession[lvl] ?? 32;
    final peak = AdmissibilityConstants.peakWeeklyKm[dist] ?? 0;

    if (!isBypassed) {
      final minReq = AdmissibilityConstants.minFreqFor(
        lvl, dist, levelHint: levelHint,
      );
      // Sentinel BLOCKED_BY_LEVEL = combinação proibida — step_goal_v3 já
      // gateia (não dá pra entrar aqui com essa combinação). Defensivo:
      if (minReq >= AdmissibilityConstants.blockedByLevel) {
        return [
          const SizedBox(height: 12),
          _WarningBanner(
            palette: palette,
            text: '${dist}K não está liberado pra esse perfil. Volta na meta '
                'e escolhe uma distância menor.',
          ),
        ];
      }
      // Falha 1: freq abaixo do mínimo
      if (frequency < minReq) {
        return [
          const SizedBox(height: 12),
          _WarningBanner(
            palette: palette,
            text: 'Pra ${dist}K nesse perfil, mínimo $minReq treinos/sem '
                '(você marcou $frequency). Aumenta os dias acima ou troca a meta.',
          ),
        ];
      }
      // Falha 2: cap volume/sessão
      if (peak > 0 && frequency > 0) {
        final projected = peak / frequency;
        if (projected > cap) {
          final needFreq = (peak / cap).ceil();
          return [
            const SizedBox(height: 12),
            _WarningBanner(
              palette: palette,
              text: 'Com $frequency treinos/sem cada sessão pra ${dist}K ficaria ~'
                  '${projected.toStringAsFixed(0)}km — acima do cap ${cap}km pro $lvl. '
                  'Mínimo $needFreq treinos/sem nessa distância.',
            ),
          ];
        }
      }
    }
    return const [];
  }
}

class _WarningBanner extends StatelessWidget {
  final RunninPalette palette;
  final String text;
  const _WarningBanner({required this.palette, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.10),
        border: Border.all(color: palette.warning.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 16, color: palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.runninType.bodySm.copyWith(
                color: palette.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LongRunChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LongRunChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.16) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.muted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.16) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.muted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Chip de frequência (1-7). Mesma linguagem do _DayChip, com estado
/// disabled (muted + sem tap) quando a opção excede a qtd de dias marcados.
class _FreqChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _FreqChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final fg = !enabled
        ? palette.muted.withValues(alpha: 0.4)
        : selected
            ? palette.primary
            : palette.muted;
    final bg = !enabled
        ? palette.surface
        : selected
            ? palette.primary.withValues(alpha: 0.16)
            : palette.surface;
    final border = !enabled
        ? palette.border.withValues(alpha: 0.5)
        : selected
            ? palette.primary
            : palette.border;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.041),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: fg,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
