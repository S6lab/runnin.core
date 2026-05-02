import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Linha de sessão de treino no plano semanal/mensal.
/// Exibe tipo, distância, pace alvo e estado (feito/pendente/hoje).
class TrainingRow extends StatelessWidget {
  final String type;
  final String? distance;
  final String? pace;
  final bool isDone;
  final bool isToday;
  final VoidCallback? onTap;

  const TrainingRow({
    super.key,
    required this.type,
    this.distance,
    this.pace,
    this.isDone = false,
    this.isToday = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final typography = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isToday ? palette.primary.withValues(alpha: 0.08) : palette.surface,
          border: Border(
            left: BorderSide(
              color: isToday
                  ? palette.primary
                  : isDone
                      ? palette.success
                      : palette.border,
              width: 3,
            ),
            bottom: BorderSide(color: palette.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.toUpperCase(),
                    style: typography.labelMd.copyWith(
                      color: isToday ? palette.primary : palette.text,
                    ),
                  ),
                  if (distance != null || pace != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      if (distance != null)
                        Text(distance!, style: typography.bodySm),
                      if (distance != null && pace != null)
                        Text('  ·  ', style: typography.bodySm),
                      if (pace != null)
                        Text(pace!, style: typography.bodySm),
                    ]),
                  ],
                ],
              ),
            ),
            if (isDone)
              Icon(Icons.check_circle_outline, size: 16, color: palette.success)
            else if (isToday)
              Icon(Icons.arrow_forward_ios, size: 12, color: palette.primary)
            else
              Icon(Icons.arrow_forward_ios, size: 12, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
