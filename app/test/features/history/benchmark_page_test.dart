import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/history/presentation/pages/benchmark_page.dart';

import '../../helpers/test_theme.dart';

void main() {
  testWidgets('BenchmarkPage renders loading state', (tester) async {
    await tester.pumpWidget(createTestApp(const BenchmarkPage()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('BENCHMARK'), findsOneWidget);
  });
}
