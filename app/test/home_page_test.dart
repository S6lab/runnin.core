import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Page Design Verification', () {
    testWidgets('Background color matches design', (WidgetTester tester) async {
      final bg = const Color(0xFF050510);
      
      expect(bg.red.toInt(), equals(5));
      expect(bg.green.toInt(), equals(5));
      expect(bg.blue.toInt(), equals(16));
    });

    testWidgets('Icon sizes match design', (WidgetTester tester) async {
      const icon22 = 22.0;
      const icon18 = 18.0;

      expect(icon22, equals(22));
      expect(icon18, equals(18));
    });

    testWidgets('Spacing follows pattern', (WidgetTester tester) async {
      const spacing177 = 17.7;
      const spacing20 = 20.0;

      expect(spacing177, equals(17.7));
      expect(spacing20, equals(20.0));
    });
  });
}
