import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/history/presentation/pages/run_detail_page.dart';

import '../../helpers/test_theme.dart';

void main() {
  testWidgets('RunDetailPage shows error for empty runId', (tester) async {
    await tester.pumpWidget(createTestApp(const RunDetailPage(runId: '')));
    await tester.pump();

    expect(find.text('Erro ao carregar corrida.'), findsOneWidget);
  });
}
