import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String iconName;
  final String? timeLabel;
  final String? ctaLabel;
  final String? ctaRoute;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.iconName,
    required this.timeLabel,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.data,
    required this.createdAt,
    required this.readAt,
    required this.dismissedAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        iconName: j['icon'] as String? ?? 'notifications_outlined',
        timeLabel: j['timeLabel'] as String?,
        ctaLabel: j['ctaLabel'] as String?,
        ctaRoute: j['ctaRoute'] as String?,
        data: (j['data'] as Map?)?.cast<String, dynamic>(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        readAt: j['readAt'] != null
            ? DateTime.tryParse(j['readAt'] as String)
            : null,
        dismissedAt: j['dismissedAt'] != null
            ? DateTime.tryParse(j['dismissedAt'] as String)
            : null,
      );

  IconData get icon => _iconFromName(iconName);
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'alarm_outlined':
      return Icons.alarm_outlined;
    case 'restaurant_outlined':
      return Icons.restaurant_outlined;
    case 'water_drop_outlined':
      return Icons.water_drop_outlined;
    case 'checklist_outlined':
      return Icons.checklist_outlined;
    case 'bedtime_outlined':
      return Icons.bedtime_outlined;
    case 'monitor_heart_outlined':
      return Icons.monitor_heart_outlined;
    case 'medical_information_outlined':
      return Icons.medical_information_outlined;
    case 'auto_awesome_outlined':
      return Icons.auto_awesome_outlined;
    case 'chat_bubble_outline':
      return Icons.chat_bubble_outline;
    default:
      return Icons.notifications_outlined;
  }
}
