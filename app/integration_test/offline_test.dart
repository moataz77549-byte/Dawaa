import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dawa_hayah/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('first open reads seed without network', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('دواء وحياة'), findsOneWidget);
    await tester.tap(find.text('جسم الإنسان').first);
    await tester.pumpAndSettle();
    expect(find.text('الجهاز التنفسي'), findsOneWidget);
  });
}
