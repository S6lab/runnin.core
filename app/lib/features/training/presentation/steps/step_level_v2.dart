import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Identidade do nível dentro da jornada de criação do plano. 5 buckets de
/// UI, mas só 3 mapeiam pro enum do server (a/b/c → iniciante, d →
/// intermediario, e → avancado). O matiz fino (a vs b vs c) vai como
/// `levelHint` pro prompt LLM.
enum PlanLevelChoice {
  neverRan('never', 'Nunca corri', 'Vou começar do zero — só caminhada/walk-run nas primeiras semanas.', 'iniciante', 'nunca_corri'),
  sporadic('sporadic', 'Corro esporadicamente', '1–2× por semana, sem regularidade. Base aeróbica frágil.', 'iniciante', 'esporadico'),
  beginnerFreq('beginner', 'Iniciante com regularidade', 'Já corro algumas vezes na semana, sem treino estruturado.', 'iniciante', 'iniciante_freq'),
  intermediate('intermediate', 'Intermediário', '15–35 km/sem · pace 5:30–6:30/km · 3–4×/sem.', 'intermediario', null),
  advanced('advanced', 'Avançado', '35+ km/sem · pace ≤5:30/km · 5+×/sem · treino estruturado.', 'avancado', null);

  final String id;
  final String label;
  final String description;
  /// Valor enviado no campo `level` do GeneratePlanInput.
  final String backendLevel;
  /// Hint adicional pro prompt; null se o backendLevel já cobre.
  final String? levelHint;
  const PlanLevelChoice(
    this.id,
    this.label,
    this.description,
    this.backendLevel,
    this.levelHint,
  );

  static PlanLevelChoice? fromId(String? id) {
    for (final c in PlanLevelChoice.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Inputs da telemetria do user (últimos 30d) usados pra sugerir o nível na
/// montagem da tela. Todos opcionais — se `runsLast30d == 0`, sugere [neverRan].
class LevelSuggestionInput {
  final int runsLast30d;
  final double totalKmLast30d;
  /// Pace médio em segundos por km (do StatsBreakdown.stats.avgPace convertido).
  final int? avgPaceSec;

  const LevelSuggestionInput({
    required this.runsLast30d,
    required this.totalKmLast30d,
    this.avgPaceSec,
  });

  double get runsPerWeek => runsLast30d / 4.345;
  double get kmPerWeek => totalKmLast30d / 4.345;
}

/// Classifica o nível sugerido a partir da telemetria do user. Thresholds
/// alinhados com a descrição dos buckets no enum acima. Função pura — sem
/// IO — testável isolada e segura pra rodar no `initState`.
PlanLevelChoice? suggestLevelFromStats(LevelSuggestionInput s) {
  if (s.runsLast30d == 0) return PlanLevelChoice.neverRan;
  final rpw = s.runsPerWeek;
  final kpw = s.kmPerWeek;
  if (rpw <= 1.2 || kpw < 8) return PlanLevelChoice.sporadic;
  if (rpw < 3 && kpw < 15) return PlanLevelChoice.beginnerFreq;
  if (rpw >= 4 && kpw >= 35) return PlanLevelChoice.advanced;
  if (rpw >= 3 && kpw >= 15) return PlanLevelChoice.intermediate;
  return PlanLevelChoice.beginnerFreq;
}

class PlanStepLevelV2 extends StatelessWidget {
  final PlanLevelChoice? selected;
  final PlanLevelChoice? suggested;
  final ValueChanged<PlanLevelChoice> onSelect;

  const PlanStepLevelV2({
    super.key,
    required this.selected,
    required this.suggested,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// SEU NÍVEL'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Como você está hoje?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'O Coach calibra a primeira semana exatamente pelo seu ponto de partida. Seja honesto — o checkpoint vai te puxar pra cima toda semana.',
        ),
        if (suggested != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.08),
              border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pelo seu histórico, sugerimos "${suggested!.label}". Confirme ou ajuste abaixo.',
                    style: context.runninType.bodySm.copyWith(
                      color: palette.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        for (final c in PlanLevelChoice.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LevelChoiceCard(
              choice: c,
              selected: selected == c,
              suggested: suggested == c,
              onTap: () => onSelect(c),
            ),
          ),
      ],
    );
  }
}

class _LevelChoiceCard extends StatelessWidget {
  final PlanLevelChoice choice;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  const _LevelChoiceCard({
    required this.choice,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    choice.label.toUpperCase(),
                    style: context.runninType.labelMd.copyWith(
                      color: selected ? palette.primary : palette.text,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (suggested)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: palette.primary.withValues(alpha: 0.18),
                    child: Text(
                      'SUGERIDO',
                      style: context.runninType.labelMd.copyWith(
                        color: palette.primary,
                        fontSize: 9,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              choice.description,
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
