import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/history/presentation/pages/history_page.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

import '../../helpers/test_theme.dart';

void main() {
  testWidgets('HistoryPage renders loading state', (tester) async {
    await tester.pumpWidget(createTestApp(const HistoryPage()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('HISTÓRICO'), findsOneWidget);
  });
}
