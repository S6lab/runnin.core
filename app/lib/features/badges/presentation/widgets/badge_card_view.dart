import 'package:flutter/material.dart';
import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;

/// Card visual do badge (TF 79 redesign alinhado aos mockups).
///
/// Estrutura comum a TODOS os badges (atingido ou bloqueado):
///   - Header: "RUNNIN.AI" left, chip secondary right (chip ganha cadeado
///     quando locked)
///   - Hero: número/valor grande em palette.text + label abaixo (caps muted)
///   - Visualização contextualizada (progress bar / antes-depois) opcional
///   - Título mixed-case bold
///   - Subtitle descritivo
///   - Status: "Atingido em DD/MM/YYYY" ou "Ainda não atingido"
///   - Divider
///   - Stats 2x2
///   - COACH IA quote (italic, box destacada)
///   - Footer: handle do user à esquerda, runninai.com à direita
class BadgeCardView extends StatelessWidget {
  final badge_e.Badge badge;
  /// Quando true (galeria), reduz padding e esconde stats + coach + footer.
  final bool compact;
  /// TF 79: render do estado "bloqueado" — opacity reduzida, chip ganha
  /// cadeado, status vira "Ainda não atingido". Hero/title/subtitle vêm
  /// da definição (sem dados reais).
  final bool locked;

  const BadgeCardView({
    super.key,
    required this.badge,
    this.compact = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Opacity(
      opacity: locked ? 0.62 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: compact ? BorderRadius.circular(10) : BorderRadius.zero,
          border: Border.all(
            color: locked
                ? palette.border
                : palette.primary,
            width: compact ? 1.2 : 1.6,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12.0 : 24.0,
          vertical: compact ? 10.0 : 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(badge: badge, locked: locked, compact: compact),
            SizedBox(height: compact ? 16.0 : 24.0),
            _Hero(badge: badge, compact: compact),
            // Hero label (KM ACUMULADOS, MIN/KM, etc) só no popup —
            // remove título do header do badge no compact pra economizar
            // espaço vertical e evitar overflow.
            if (!compact) ...[
              const SizedBox(height: 8.0),
              Text(
                _heroLabel(),
                style: type.labelCaps.copyWith(
                  color: palette.muted,
                  fontSize: 13.0,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            // Visualização contextualizada: template muda por tipo de badge.
            // No compact (galeria), esconde a visualização pra caber no
            // aspect ratio do GridView. Popup mostra completo.
            if (!locked && !compact) ...[
              Builder(
                builder: (_) {
                  final viz = _selectVisualization();
                  if (viz == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: viz,
                  );
                },
              ),
            ],
            SizedBox(height: compact ? 12.0 : 20.0),
            Text(
              badge.title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: type.dataMd.copyWith(
                // Título usa palette.secondary (cor #2 da skin) — destaque
                // diferente do hero (palette.text branco).
                color: palette.secondary,
                fontSize: compact ? 14.0 : 26.0,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: compact ? 4.0 : 6.0),
            // Subtítulo só no popup (no compact ocupa muito espaço e quebra
            // overflow vertical do GridView).
            if (!compact)
              Text(
                badge.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm.copyWith(
                  color: palette.muted,
                  fontSize: 14.0,
                  height: 1.35,
                ),
              ),
            SizedBox(height: compact ? 6.0 : 10.0),
            Text(
              // Data da corrida que conquistou (achievedAt) — em badges
              // retroativos o unlockedAt era a data do eval em lote.
              // Galeria (compact): só "em 10-jun-26"; card cheio mantém
              // o prefixo "Atingido".
              locked
                  ? 'Ainda não atingido'
                  : compact
                      ? 'em ${_fmtDate(badge.achievedOrUnlockedAt)}'
                      : 'Atingido em ${_fmtDate(badge.achievedOrUnlockedAt)}',
              style: type.bodyXs.copyWith(
                color: palette.muted.withValues(alpha: 0.7),
                fontSize: compact ? 10.0 : 11.0,
                letterSpacing: 0.3,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 18.0),
              Container(height: 1, color: palette.border),
              const SizedBox(height: 16.0),
              _StatsGrid(badge: badge, locked: locked),
              const SizedBox(height: 18.0),
              if (_resolveCoachQuote() != null) ...[
                _CoachQuote(
                  quote: _resolveCoachQuote()!,
                  locked: locked,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _heroLabel() {
    final id = badge.badgeId;
    if (RegExp(r'^cumulative_\d+k$').hasMatch(id)) return 'KM ACUMULADOS';
    if (RegExp(r'^single_run_\d+k$').hasMatch(id)) return 'EM UMA CORRIDA';
    if (RegExp(r'^streak_\d+_days$').hasMatch(id)) return 'DIAS SEGUIDOS';
    if (RegExp(r'^pace_sub_').hasMatch(id)) return 'MIN/KM';
    switch (badge.category) {
      case badge_e.BadgeCategory.report:
        return 'RESUMO DO PERÍODO';
      case badge_e.BadgeCategory.first:
        return 'MARCO HISTÓRICO';
      default:
        return 'MARCO';
    }
  }

  /// Escolhe o template de visualização baseado no tipo do badge.
  /// Retorna null quando não há visualização adicional (hero domina).
  Widget? _selectVisualization() {
    final id = badge.badgeId;
    final progress = _resolveProgress();
    if (progress != null) {
      return _ProgressBar(progress: progress, compact: compact);
    }
    final pace = RegExp(r'^pace_sub_(\d+)_(\d+)$').firstMatch(id);
    if (pace != null) {
      return _BeforeAfter(
        beforeLabel: 'INÍCIO',
        beforeValue: _firstPaceLabel(),
        afterLabel: 'PR',
        afterValue: badge.stats.paceMinKm ?? badge.primaryDisplay,
        delta: _paceDelta(),
        compact: compact,
      );
    }
    final extra = badge.stats.extra;
    final bars = extra['dailyBars'];
    if (bars is List && bars.isNotEmpty) {
      return _VerticalBars(
        labels: List<String>.from(extra['dailyLabels'] as List? ?? []),
        values: bars.map((e) => (e as num).toDouble()).toList(),
        unit: extra['barUnit']?.toString() ?? '',
        compact: compact,
      );
    }
    return null;
  }

  /// Pace inicial vem em `stats.extra.firstPace` quando server fornece;
  /// fallback "—" pra não quebrar UI quando ausente.
  String _firstPaceLabel() {
    final first = badge.stats.extra['firstPace'];
    if (first is String && first.isNotEmpty) return first;
    return '—';
  }

  /// Delta de segundos (string ex.: "-117s") quando server fornece;
  /// fallback vazio.
  /// Coach quote vem do server (`stats.extra.coachQuote`), gerado no
  /// momento do unlock baseado em dados reais do user. Null = box some.
  String? _resolveCoachQuote() {
    final q = badge.stats.extra['coachQuote'];
    if (q is String && q.trim().isNotEmpty) return q.trim();
    return null;
  }

  String? _paceDelta() {
    final delta = badge.stats.extra['paceDeltaSec'];
    if (delta is num) {
      final s = delta.round();
      final sign = s <= 0 ? '' : '+';
      return '$sign${s}s';
    }
    return null;
  }

  _ProgressInfo? _resolveProgress() {
    final id = badge.badgeId;
    final stats = badge.stats;
    final cumulative = RegExp(r'^cumulative_(\d+)k$').firstMatch(id);
    if (cumulative != null) {
      final target = double.tryParse(cumulative.group(1)!);
      final current = stats.distanceKm;
      if (target == null || target <= 0) return null;
      return _ProgressInfo(
        fraction: ((current ?? target) / target).clamp(0.0, 1.0),
        currentLabel: '${(current ?? target).toStringAsFixed(1)} km atual',
        startLabel: '0 km',
        endLabel: '${target.toStringAsFixed(0)} km',
      );
    }
    final single = RegExp(r'^single_run_(\d+)k$').firstMatch(id);
    if (single != null) {
      final target = double.tryParse(single.group(1)!);
      final current = stats.distanceKm;
      if (target == null || target <= 0) return null;
      return _ProgressInfo(
        fraction: ((current ?? target) / target).clamp(0.0, 1.0),
        currentLabel: '${(current ?? target).toStringAsFixed(1)} km atingidos',
        startLabel: '0 km',
        endLabel: '${target.toStringAsFixed(0)} km',
      );
    }
    final streak = RegExp(r'^streak_(\d+)_days$').firstMatch(id);
    if (streak != null) {
      final target = double.tryParse(streak.group(1)!);
      final current = (stats.extra['streak'] as num?)?.toDouble();
      if (target == null || target <= 0) return null;
      return _ProgressInfo(
        fraction: ((current ?? target) / target).clamp(0.0, 1.0),
        currentLabel: '${(current ?? target).toStringAsFixed(0)} dias',
        startLabel: '0',
        endLabel: '${target.toStringAsFixed(0)} dias',
      );
    }
    return null;
  }

  static const _monthsAbbr = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  /// "10-jun-26" — curto pro card da galeria não disputar espaço.
  String _fmtDate(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = d.day.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '$dd-${_monthsAbbr[d.month - 1]}-$yy';
  }

}

class _Header extends StatelessWidget {
  final badge_e.Badge badge;
  final bool locked;
  final bool compact;
  const _Header({required this.badge, required this.locked, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ".AI" SEMPRE acompanhado de "RUNNIN" (lockup canônico do app),
        // mesmo no compact. Cor do ".AI" preta sólida pra garantir leitura
        // em todas as skins (auto-contraste falhava em magenta/volt).
        Icon(
          Icons.keyboard_double_arrow_right,
          size: compact ? 11.0 : 16.0,
          color: palette.primary,
        ),
        const SizedBox(width: 3),
        Text(
          'RUNNIN',
          style: type.labelCaps.copyWith(
            color: palette.text,
            fontSize: compact ? 8.5 : 12.0,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 3.0 : 5.0,
            vertical: compact ? 1.0 : 2.0,
          ),
          color: palette.primary,
          child: Text(
            '.AI',
            style: type.labelCaps.copyWith(
              color: const Color(0xFF0A0A0F),
              fontSize: compact ? 7.5 : 10.0,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        if (badge.badgeChip != null)
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7.0 : 11.0,
                vertical: compact ? 4.0 : 6.0,
              ),
              decoration: BoxDecoration(
                // TF 79: chip ganha palette.secondary (cor #2 da skin),
                // contrasta com chevron/.AI/border que são primary.
                color: palette.secondary.withValues(alpha: 0.18),
                border: Border.all(
                  color: palette.secondary.withValues(alpha: 0.7),
                  width: 0.8,
                ),
              ),
              // Popup tem espaço pra label completa ("ACUMULADO 50K") —
              // maxWidth alargado evita ellipsis em chips longos.
              constraints: BoxConstraints(maxWidth: compact ? 140 : 320),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked) ...[
                    Icon(
                      Icons.lock_outline,
                      size: compact ? 10.0 : 13.0,
                      color: palette.warning,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      badge.badgeChip!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: type.labelCaps.copyWith(
                        color: palette.secondary,
                        fontSize: compact ? 8.5 : 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final badge_e.Badge badge;
  final bool compact;
  const _Hero({required this.badge, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              badge.primaryDisplay.isEmpty ? '—' : badge.primaryDisplay,
              maxLines: 1,
              style: TextStyle(
                color: palette.text,
                fontSize: compact ? 42.0 : 96.0,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: -2,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        if (badge.primaryUnit != null) ...[
          const SizedBox(width: 6),
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 6.0 : 14.0),
            child: Text(
              badge.primaryUnit!,
              style: type.labelMd.copyWith(
                color: palette.muted,
                fontSize: compact ? 13.0 : 18.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressInfo {
  final double fraction;
  final String currentLabel;
  final String startLabel;
  final String endLabel;
  const _ProgressInfo({
    required this.fraction,
    required this.currentLabel,
    required this.startLabel,
    required this.endLabel,
  });
}

class _ProgressBar extends StatelessWidget {
  final _ProgressInfo progress;
  final bool compact;
  const _ProgressBar({required this.progress, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: Stack(
            children: [
              Container(height: 4, color: palette.surfaceAlt),
              FractionallySizedBox(
                widthFactor: progress.fraction.clamp(0.0, 1.0),
                child: Container(height: 4, color: palette.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              progress.startLabel,
              style: type.bodyXs.copyWith(
                color: palette.muted,
                fontSize: compact ? 9.5 : 11.0,
              ),
            ),
            const Spacer(),
            Text(
              progress.currentLabel,
              style: type.bodyXs.copyWith(
                color: palette.text,
                fontSize: compact ? 9.5 : 11.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              progress.endLabel,
              style: type.bodyXs.copyWith(
                color: palette.muted,
                fontSize: compact ? 9.5 : 11.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final badge_e.Badge badge;
  final bool locked;
  const _StatsGrid({required this.badge, required this.locked});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final s = badge.stats;
    final cells = <_StatCell>[];
    if (locked) {
      cells.add(const _StatCell('STATUS', 'Bloqueado'));
      cells.add(const _StatCell('PROGRESSO', '—'));
    } else {
      if (s.distanceKm != null) {
        cells.add(_StatCell('DISTÂNCIA', '${s.distanceKm!.toStringAsFixed(1)} km'));
      }
      if (s.paceMinKm != null) {
        cells.add(_StatCell('PACE', '${s.paceMinKm}/km'));
      }
      if (s.durationS != null) {
        cells.add(_StatCell('DURAÇÃO', _fmtDuration(s.durationS!)));
      }
      if (s.bestPaceMinKm != null) {
        cells.add(_StatCell('MELHOR PACE', '${s.bestPaceMinKm}/km'));
      }
      if (s.avgBpm != null) {
        cells.add(_StatCell('FC MÉDIA', '${s.avgBpm}'));
      }
      if (s.weekKm != null) {
        cells.add(_StatCell('SEMANA', '${s.weekKm!.toStringAsFixed(1)} km'));
      }
      if (s.monthKm != null) {
        cells.add(_StatCell('MÊS', '${s.monthKm!.toStringAsFixed(1)} km'));
      }
    }
    if (cells.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final right = i + 1 < cells.length ? cells[i + 1] : null;
      rows.add(_buildRow(palette, type, cells[i], right));
      if (i + 2 < cells.length) rows.add(const SizedBox(height: 8.0));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _buildRow(dynamic palette, dynamic type, _StatCell left, _StatCell? right) {
    return Row(
      children: [
        Expanded(child: _cell(palette, type, left)),
        const SizedBox(width: 8.0),
        Expanded(
          child: right != null
              ? _cell(palette, type, right)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _cell(dynamic palette, dynamic type, _StatCell c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.label,
            style: type.labelCaps.copyWith(
              color: palette.muted,
              fontSize: 9.5,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.value,
            style: type.labelMd.copyWith(
              color: palette.text,
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}min';
  }
}

class _StatCell {
  final String label;
  final String value;
  const _StatCell(this.label, this.value);
}

/// Box "COACH IA" com a quote gerada pelo server (campo `stats.extra.coachQuote`).
/// Não usa fallback hardcoded — quando server não fornece, o box não é renderizado.
class _CoachQuote extends StatelessWidget {
  final String quote;
  final bool locked;
  const _CoachQuote({required this.quote, required this.locked});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COACH IA',
            style: type.labelCaps.copyWith(
              color: palette.muted,
              fontSize: 9.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"$quote"',
            style: type.bodySm.copyWith(
              color: palette.text.withValues(
                alpha: locked ? 0.55 : 0.88,
              ),
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes → depois: usado pra Pace PR (mostra pace inicial vs PR atual).
/// Reutilizável pra outros badges com transição inicial → final.
class _BeforeAfter extends StatelessWidget {
  final String beforeLabel;
  final String beforeValue;
  final String afterLabel;
  final String afterValue;
  final String? delta;
  final bool compact;
  const _BeforeAfter({
    required this.beforeLabel,
    required this.beforeValue,
    required this.afterLabel,
    required this.afterValue,
    required this.compact,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _cell(
            palette: palette,
            type: type,
            label: beforeLabel,
            value: beforeValue,
            highlighted: false,
          ),
        ),
        SizedBox(
          width: compact ? 56.0 : 80.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward,
                color: palette.muted,
                size: compact ? 14.0 : 18.0,
              ),
              if (delta != null && delta!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  delta!,
                  style: type.bodyXs.copyWith(
                    color: palette.muted,
                    fontSize: compact ? 9.5 : 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _cell(
            palette: palette,
            type: type,
            label: afterLabel,
            value: afterValue,
            highlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _cell({
    required dynamic palette,
    required dynamic type,
    required String label,
    required String value,
    required bool highlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(
          color: highlighted ? palette.primary : palette.border,
          width: highlighted ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: type.labelCaps.copyWith(
              color: palette.muted,
              fontSize: 9.5,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: type.labelMd.copyWith(
              color: palette.text,
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras verticais por dia/período — usado pra sleep, week summary,
/// streak markers. Cada coluna mostra um valor com label embaixo.
class _VerticalBars extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String unit;
  final bool compact;
  const _VerticalBars({
    required this.labels,
    required this.values,
    required this.unit,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    if (values.isEmpty) return const SizedBox.shrink();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final base = maxV > 0 ? maxV : 1.0;
    final barH = compact ? 36.0 : 56.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final v = values[i];
        final frac = (v / base).clamp(0.05, 1.0);
        final label = i < labels.length ? labels[i] : '';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 2.0 : 3.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${v.toStringAsFixed(v >= 10 ? 0 : 1)}$unit',
                  style: type.bodyXs.copyWith(
                    color: palette.text,
                    fontSize: compact ? 9.0 : 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: barH * frac,
                  width: double.infinity,
                  color: palette.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: type.labelCaps.copyWith(
                    color: palette.muted,
                    fontSize: compact ? 9.0 : 10.0,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

