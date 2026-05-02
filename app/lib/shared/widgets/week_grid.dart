import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

enum WeekDayStatus { done, today, rest, planned, empty }

class WeekDayData {
  final String label; // 'SEG', 'TER', etc.
  final WeekDayStatus status;
  final String? detail; // tipo de treino ou distância

  const WeekDayData({
    required this.label,
    required this.status,
    this.detail,
  });
}

/// Grade semanal com 7 células e estados visuais distintos.
/// Usado em home e training.
class WeekGrid extends StatelessWidget {
  final List<WeekDayData> days;
  final ValueChanged<int>? onDayTap;

  const WeekGrid({super.key, required this.days, this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Row(
      children: List.generate(days.length, (i) {
        final day = days[i];
        return Expanded(
          child: GestureDetector(
            onTap: onDayTap != null ? () => onDayTap!(i) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Text(
                    day.label,
                    style: type.labelCaps.copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: _bgColor(day.status, palette),
                      border: Border.all(
                        color: _borderColor(day.status, palette),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _icon(day.status, palette),
                  ),
                  if (day.detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      day.detail!,
                      style: type.labelCaps.copyWith(fontSize: 8),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _bgColor(WeekDayStatus status, RunninPalette p) => switch (status) {
    WeekDayStatus.done => p.primary.withValues(alpha: 0.15),
    WeekDayStatus.today => p.primary,
    WeekDayStatus.rest => p.surface,
    WeekDayStatus.planned => p.surface,
    WeekDayStatus.empty => p.surface,
  };

  Color _borderColor(WeekDayStatus status, RunninPalette p) => switch (status) {
    WeekDayStatus.done => p.primary.withValues(alpha: 0.4),
    WeekDayStatus.today => p.primary,
    WeekDayStatus.rest => p.border,
    WeekDayStatus.planned => p.border,
    WeekDayStatus.empty => p.border.withValues(alpha: 0.3),
  };

  Widget _icon(WeekDayStatus status, RunninPalette p) => switch (status) {
    WeekDayStatus.done => Icon(Icons.check, size: 14, color: p.primary),
    WeekDayStatus.today => Icon(Icons.play_arrow, size: 14, color: p.background),
    WeekDayStatus.rest => Icon(Icons.bed_outlined, size: 12, color: p.muted),
    WeekDayStatus.planned => Icon(Icons.circle_outlined, size: 10, color: p.muted),
    WeekDayStatus.empty => const SizedBox.shrink(),
  };
}
