import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dawa_hayah/main.dart' as app;
import 'package:dawa_hayah/app.dart';
import 'package:dawa_hayah/core/providers.dart';
import 'package:dawa_hayah/data/packs/manifest.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Neon pack install on Android', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DawaApp)),
    );
    final db = container.read(databaseProvider);
    final manager = container.read(managerProvider);
    if ((await db.packs()).isNotEmpty) {
      await manager.remove('circulation-demo');
    }
    final manifest = PackManifest(
      await container.read(apiProvider).manifest('circulation-demo'),
    );
    await manager.install(manifest);
    expect(manager.status, 'complete', reason: manager.error);
    expect(
      (await db.packs()).firstWhere(
        (p) => p['id'] == 'circulation-demo',
      )['version'],
      1,
    );
    if ((await db.packs()).any((p) => p['id'] == 'medical-identities')) {
      await manager.remove('medical-identities');
    }
    await manager.install(
      PackManifest(
        await container.read(apiProvider).manifest('medical-identities'),
      ),
    );
    expect(manager.status, 'complete', reason: manager.error);
    final identity = (await db.contents(search: 'RxCUI:161')).single;
    await db.bookmark(identity['id']);
    await db.recordRead(identity['id']);
    expect(await db.content('cloud-circulation'), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
