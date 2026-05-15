import 'package:flutter/material.dart';
import 'package:runnin/core/theme/_theme.dart';

enum PlanTaskStatus { done, active, pending }

class PlanTaskRow extends StatelessWidget {
  final PlanTaskStatus status;
  final String label;
  final String mainText;
  final String? detail;

  const PlanTaskRow({
    super.key,
    required this.status,
    required this.label,
    required this.mainText,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    late final Color bulletColor;
    late final String bulletText;
    late final double opacity;

    switch (status) {
      case PlanTaskStatus.done:
        bulletColor = palette.primary;
        bulletText = 'OK';
        opacity = 1.0;
        break;
      case PlanTaskStatus.active:
        bulletColor = Colors.white;
        bulletText = '●';
        opacity = 1.0;
        break;
      case PlanTaskStatus.pending:
        bulletColor = const Color(0x8CFFFFFF);
        bulletText = '○';
        opacity = 0.15;
        break;
    }

    final commonTextStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
    );

    late final Color mainTextColor;
    if (status == PlanTaskStatus.done || status == PlanTaskStatus.active) {
      mainTextColor = const Color(0xB3FFFFFF);
    } else {
      mainTextColor = const Color(0x8CFFFFFF);
    }

    final detailStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
      color: const Color(0x40FFFFFF),
    );

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: bulletColor,
    );

    return Opacity(
      opacity: opacity,
      child: Container(
        height: _getRowHeight(status),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                bulletText,
                style: labelStyle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mainText, style: commonTextStyle.copyWith(color: mainTextColor)),
                  if (detail != null && status != PlanTaskStatus.pending) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: detailStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getRowHeight(PlanTaskStatus status) {
    switch (status) {
      case PlanTaskStatus.done:
        return 73.463;
      case PlanTaskStatus.active:
        return 49.465;
      case PlanTaskStatus.pending:
        return 31.997;
    }
  }
}
