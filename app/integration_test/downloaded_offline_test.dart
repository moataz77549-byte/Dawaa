import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dawa_hayah/main.dart' as app;
import 'package:dawa_hayah/app.dart';
import 'package:dawa_hayah/core/providers.dart';
import 'package:dawa_hayah/features/anatomy/viewer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'installed text PNG and GLB render with device network disabled',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DawaApp)),
      );
      final db = container.read(databaseProvider);
      final pack = (await db.packs()).firstWhere(
        (p) => p['id'] == 'circulation-demo',
      );
      final identity = (await db.contents(search: 'RxCUI:161')).single;
      expect(identity['title_ar'], 'أسيتامينوفين');
      expect((await db.provenanceFor(identity['id']))!['source_id'], 'rxnorm');
      expect(await db.bookmarked(identity['id']), true);
      router.go('/content/${identity['id']}');
      await tester.pumpAndSettle();
      expect(find.textContaining('RxCUI: 161'), findsOneWidget);
      expect(find.textContaining('الاسم العربي مسودة مستقلة'), findsOneWidget);
      expect((await db.content('cloud-circulation'))!['body_ar'], isNotEmpty);
      await tester.pumpWidget(
        MaterialApp(home: Image.file(File('${pack['directory']}/diagram.png'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: ModelViewer(file: File('${pack['directory']}/demo.glb')),
        ),
      );
      for (
        var i = 0;
        i < 60 && find.text('3D ready / جاهز').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('3D ready / جاهز'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
