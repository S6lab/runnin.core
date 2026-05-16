// Test variants for NotificationCard component
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/shared/widgets/notification_card.dart';

void main() {
  testWidgets('NotificationCard renders with all props', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: NotificationCard(
          icon: Icons.email,
          title: 'MELHOR HORÁRIO',
          subtitle: '06:30',
          timestamp: 'AGORA',
          borderColor: Colors.cyan,
        ),
      ),
    );

    expect(find.text('MELHOR HORÁRIO'), findsOneWidget);
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('AGORA'), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);
  });

  testWidgets('NotificationCard supports all 5 variants from HOME.md', (WidgetTester tester) async {
    final List<Map<String, dynamic>> variants = [
      {'name': 'notification 1 (cyan)', 'color': const Color(0xFF00D4FF)},
      {'name': 'notification 2 (yellow)', 'color': const Color(0xFFEAB308)},
      {'name': 'notification 3 (blue)', 'color': const Color(0xFF3B82F6)},
      {'name': 'notification 4 (orange)', 'color': const Color(0xFFFF6B35)},
      {'name': 'notification 5 (purple)', 'color': const Color(0xFF8B5CF6)},
    ];

    for (final variant in variants) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: NotificationCard(
            icon: Icons.notifications,
            title: variant['name'] as String,
            subtitle: 'Notification subtitle',
            timestamp: 'NOW',
            borderColor: variant['color'] as Color,
          ),
        ),
      );

      expect(find.byType(NotificationCard), findsOneWidget);
    }
  });
}
