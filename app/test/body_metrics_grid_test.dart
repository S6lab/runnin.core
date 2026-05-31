import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/body_metrics_grid.dart';

void main() {
  group('BodyMetricsGrid Widget Tests', () {
    testWidgets('Displays weight and height metrics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: BodyMetricsGrid(weight: 75.5, height: 180),
        ),
      );

      expect(find.text('PESO'), findsOneWidget);
      expect(find.text('ALTURA'), findsOneWidget);
    });

    testWidgets('Shows em-dash for null values', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: BodyMetricsGrid(weight: null, height: null),
        ),
      );

      expect(find.text('—'), findsNWidgets(4));
    });

    testWidgets('Follows 17.7px spacing pattern', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: BodyMetricsGrid(weight: 70, height: 175),
        ),
      );

      expect(find.text('PESO'), findsOneWidget);
      expect(find.text('ALTURA'), findsOneWidget);
    });

    testWidgets('All 4 metrics displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: BodyMetricsGrid(
            weight: 70,
            height: 175,
            age: 28,
            weeklyFrequency: 3,
          ),
        ),
      );

      expect(find.text('PESO'), findsOneWidget);
      expect(find.text('ALTURA'), findsOneWidget);
      expect(find.text('IDADE'), findsOneWidget);
      expect(find.text('FREQ'), findsOneWidget);
    });

    testWidgets('Correct units displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              RunninThemeTokens(palette: RunninSkin.artico.palette),
            ],
          ),
          home: BodyMetricsGrid(weight: 70, height: 175),
        ),
      );

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
    });
  });
}
