import 'package:flutter/material.dart';
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
  });

  final String label;
  final WeekDayCellStatus status;
  final String? type;
  final String? distance;
  final String? paceOrDuration;

  bool get isRest => status == WeekDayCellStatus.rest;
  bool get isDone => status == WeekDayCellStatus.done;
  bool get isToday => status == WeekDayCellStatus.today;
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
        _BodyCell(data: data),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.data});

  final WeekDayCellData data;

  @override
  Widget build(BuildContext context) {
    final bg = switch (data.status) {
      WeekDayCellStatus.done => FigmaColors.brandCyan,
      WeekDayCellStatus.today =>
        const Color(0x1700D4FF), // rgba(0,212,255,0.09) per HOME.md
      _ => Colors.transparent,
    };
    final fg = switch (data.status) {
      WeekDayCellStatus.done => FigmaColors.bgBase,
      WeekDayCellStatus.today => FigmaColors.brandCyan,
      _ => FigmaColors.textSecondary,
    };

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
    if (data.isRest) {
      return _RestBody();
    }

    final accentDim = data.status == WeekDayCellStatus.planned;
    final isTodayAccent = data.isToday;

    final iconColor = isTodayAccent
        ? FigmaColors.brandCyan
        : data.isDone
            ? FigmaColors.brandCyan
            : FigmaColors.textDim;

    final typeColor = isTodayAccent
        ? FigmaColors.brandCyan
        : accentDim
            ? FigmaColors.textDim
            : FigmaColors.brandCyan;

    final distanceColor = isTodayAccent
        ? FigmaColors.brandOrange
        : data.isDone
            ? FigmaColors.brandCyan
            : FigmaColors.textDim;

    final paceColor = isTodayAccent
        ? FigmaColors.brandOrange
        : FigmaColors.textDim;

    final icon = data.isDone ? Icons.check : Icons.fiber_manual_record;
    final iconSize = data.isDone ? 12.0 : 6.0;

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
          if (data.type != null)
            Text(
              data.type!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                height: 13.5 / 9,
                fontWeight: FontWeight.w400,
                color: typeColor,
              ),
            ),
          if (data.distance != null)
            Text(
              data.distance!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                height: 19.5 / 13,
                fontWeight: FontWeight.w700,
                color: distanceColor,
              ),
            ),
          if (data.paceOrDuration != null)
            Text(
              data.paceOrDuration!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                height: 13.5 / 9,
                fontWeight: FontWeight.w500,
                color: paceColor,
              ),
            ),
          if (data.isToday)
            Text(
              'HOJE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                height: 12 / 8,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: FigmaColors.brandCyan,
              ),
            ),
        ],
      ),
    );
  }
}

class _RestBody extends StatelessWidget {
  const _RestBody();

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
      child: Text(
        'DESC',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          height: 16.5 / 11,
          letterSpacing: 1.65,
          fontWeight: FontWeight.w500,
          color: FigmaColors.textSecondary,
        ),
      ),
    );
  }
}
