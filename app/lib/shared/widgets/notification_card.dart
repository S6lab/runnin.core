import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? timestamp;
  final Color borderColor;

  const NotificationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.timestamp,
    required this.borderColor,
  });

  static List<NotificationCard> sampleNotifications() {
    return [
      NotificationCard(
        icon: Icons.access_time,
        title: 'MELHOR HORÁRIO',
        subtitle: '06:30',
        timestamp: 'AGORA',
        borderColor: NotificationColors.notification1,
      ),
      NotificationCard(
        icon: Icons.restaurant,
        title: 'PREPARO NUTRICIONAL',
        subtitle: 'Carb-loading e hidratação pré-treino',
        timestamp: '05:30',
        borderColor: NotificationColors.notification2,
      ),
      NotificationCard(
        icon: Icons.local_drink,
        title: 'HIDRATAÇÃO',
        subtitle: '72% (1.8L/2.5L)',
        timestamp: 'CONTÍNUO',
        borderColor: NotificationColors.notification3,
      ),
      NotificationCard(
        icon: Icons.checklist,
        title: 'CHECKLIST PRÉ-EASY RUN',
        subtitle: 'Aquecimento e mobilização',
        timestamp: '06:00',
        borderColor: NotificationColors.notification4,
      ),
      NotificationCard(
        icon: Icons.air,
        title: 'SONO → PERFORMANCE',
        subtitle: 'Fase REM completada',
        timestamp: '21:00',
        borderColor: NotificationColors.notification5,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      height: 62.4,
      padding: const EdgeInsets.fromLTRB(17.7, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: borderColor, width: 1.741),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: type.labelMd.copyWith(color: borderColor),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: type.bodySm.copyWith(color: palette.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (timestamp != null) ...[
            Text(
              timestamp!,
              style: type.labelCaps.copyWith(color: palette.muted),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, size: 10, color: palette.muted),
          ],
        ],
      ),
    );
  }
}
