import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// State of a day cell in the [WeekGrid].
enum WeekDayCellStatus {
  /// Past + completed session — header cyan solid + cyan accents.
  done,

  /// Today's planned session — header tinted cyan + orange accents on body.
  today,

  /// Future planned training day (not yet done) — dim text + transparent bg.
  planned,

  /// Rest day — "DESC" label, no body content.
  rest,

  /// Empty placeholder cell.
  empty,
}

/// Per-cell payload for [WeekGrid]. One per day of the week (7 total).
///
/// Field semantics map to HOME.md §03 spec:
/// - [label] — short day name ("SEG", "TER", …)
/// - [status] — see [WeekDayCellStatus]
/// - [type] — workout abbreviation ("EASY", "INT", "TEMPO", "LONG"). null for rest.
/// - [distance] — short distance label ("4K", "5K"). null for rest.
/// - [paceOrDuration] — secondary line such as "6:10/km · 26:00". null when absent.
class WeekDayCellData {
  const WeekDayCellData({
    required this.label,
    required this.status,
    this.type,
    this.distance,
    this.paceOrDuration,
    this.executed = false,
    this.isToday = false,
  });

  final String label;
  final WeekDayCellStatus status;
  final String? type;
  final String? distance;
  final String? paceOrDuration;

  /// Corrida da sessão já realizada. Controla o ícone (check vs ponto)
  /// independentemente do [status] (que define a cor do cabeçalho). Assim
  /// o dia de HOJE já concluído também mostra o check.
  final bool executed;

  /// Marca o dia corrente. Flag independente do [status] porque um dia de
  /// HOJE pode ser de descanso (sem sessão) e ainda assim precisar do
  /// destaque visual no cabeçalho. Antes era derivado de status==today,
  /// mas isso perdia o destaque quando session era null.
  final bool isToday;

  bool get isRest => status == WeekDayCellStatus.rest;
  bool get isDone => status == WeekDayCellStatus.done;
}

/// 7-column weekly grid per `docs/figma/screens/HOME.md` §03 (lines 105–131).
///
/// Each column is two stacked Figma cells:
///   - Header: 37.711 px tall, bottom-border 1.741, bg per cell state
///   - Body:   110.44 px tall, side+bottom borders 1.741, bg surface 3%
///
/// The component is content-driven via [cells] (length 7).
class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.cells, this.onDayTap});

  final List<WeekDayCellData> cells;
  final ValueChanged<int>? onDayTap;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == 7, 'WeekGrid expects exactly 7 day cells');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cells.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: onDayTap == null ? null : () => onDayTap!(i),
              behavior: HitTestBehavior.opaque,
              child: _DayColumn(data: cells[i]),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.data});

  final WeekDayCellData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderCell(data: data),
        if (data.isRest) _RestBody(isToday: data.isToday) else _BodyCell(data: data),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.data});

  final WeekDayCellData data;

  @override
  Widget build(BuildContext context) {
    // Convenção (invertida): HOJE em primary (chamativo, "ação ativa") e
    // dia já FEITO em secondary (mais discreto, "consolidado"). isToday tem
    // precedência: dia atual sem sessão (descanso) ainda destaca o header.
    final Color bg;
    if (data.isToday) {
      bg = context.runninPalette.primary;
    } else if (data.status == WeekDayCellStatus.done) {
      bg = context.runninPalette.secondary;
    } else {
      bg = Colors.transparent;
    }
    final fg = data.isToday || data.status == WeekDayCellStatus.done
        ? FigmaColors.bgBase
        : FigmaColors.textSecondary;

    return Container(
      height: 37.711,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Text(
        data.label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          height: 16.5 / 11,
          letterSpacing: 1.65,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.data});

  final WeekDayCellData data;

  @override
  Widget build(BuildContext context) {
    final accentDim = data.status == WeekDayCellStatus.planned;
    final isTodayAccent = data.isToday;
    // Concluído = corrida realizada (executed) OU dia passado marcado como
    // done. Independe da cor do cabeçalho → HOJE concluído também vira check.
    final done = data.executed || data.isDone;

    // Cores invertidas vs versão anterior: done usa secondary, today/planned
    // usam primary. Convenção: "agora/futuro = primary" / "feito = secondary".
    final iconColor = done
        ? context.runninPalette.secondary
        : isTodayAccent
            ? context.runninPalette.primary
            : FigmaColors.textDim;

    final typeColor = isTodayAccent
        ? context.runninPalette.primary
        : accentDim
            ? FigmaColors.textDim
            : done
                ? context.runninPalette.secondary
                : context.runninPalette.primary;

    final distanceColor = isTodayAccent
        ? context.runninPalette.primary
        : data.isDone
            ? context.runninPalette.secondary
            : FigmaColors.textDim;

    final paceColor = isTodayAccent
        ? context.runninPalette.primary
        : done
            ? context.runninPalette.secondary
            : FigmaColors.textDim;

    final icon = done ? Icons.check : Icons.fiber_manual_record;
    final iconSize = done ? 12.0 : 6.0;

    return Container(
      height: 110.44,
      padding: const EdgeInsets.fromLTRB(9.741, 8, 9.741, 9.741),
      decoration: const BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border(
          left: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
          right: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
          bottom: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          // Colunas têm ~1/7 da largura → FittedBox(scaleDown) mantém cada
          // texto em UMA linha, escalando pra caber sem cortar/quebrar.
          if (data.type != null)
            _FitText(
              data.type!,
              GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: typeColor,
              ),
            ),
          if (data.distance != null)
            _FitText(
              data.distance!,
              GoogleFonts.jetBrainsMono(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: distanceColor,
              ),
            ),
          if (data.paceOrDuration != null)
            _FitText(
              data.paceOrDuration!,
              GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: paceColor,
              ),
            ),
          if (data.isToday)
            _FitText(
              'HOJE',
              GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 1.2,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: context.runninPalette.secondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto de uma linha que escala pra caber na largura da coluna (sem cortar
/// nem quebrar). Mantém o tamanho natural quando há espaço; reduz só quando
/// a coluna é estreita demais.
class _FitText extends StatelessWidget {
  const _FitText(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

class _RestBody extends StatelessWidget {
  const _RestBody({this.isToday = false});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110.44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border(
          left: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
          right: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
          bottom: BorderSide(color: FigmaColors.borderDefault, width: 1.741),
        ),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DESC',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              letterSpacing: 1.65,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSecondary,
            ),
          ),
          if (isToday) ...[
            const SizedBox(height: 4),
            Text(
              'HOJE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                height: 1.2,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: context.runninPalette.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
