import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dawa_hayah/data/local/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'seed is bilingual, idempotent, searchable and preserves personal data',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final seed = File('assets/seed/content.json').readAsStringSync();
      await db.seed(json: seed);
      await db.bookmark('circulation');
      await db.recordRead('circulation');
      await db.setSetting('language', 'en');
      await db.seed(json: seed);
      expect((await db.contents()).length, 14);
      expect((await db.content('circulation'))!['body_en'], isNotEmpty);
      expect(await db.bookmarked('circulation'), isTrue);
      expect(await db.setting('language'), 'en');
      expect((await db.contents(search: 'الدورة')).single['id'], 'circulation');
      expect(normalize('إِنْسان آدَم'), normalize('انسان ادم'));
    },
  );
  test('interrupted jobs recover as paused', () async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    await db.job('test', 'downloading', 5, 10);
    await db.recoverJobs();
    expect((await db.jobs()).single['status'], 'paused');
  });
}
