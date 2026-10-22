import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:dawa_hayah/data/local/database.dart';

void main() {
  test(
    'v1 upgrade preserves content, packs, preferences, favorites and history',
    () async {
      final directory = await Directory.systemTemp.createTemp('dawa-upgrade-');
      final file = File('${directory.path}/existing.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      for (final sql in LocalDatabase.schema) {
        old.execute(sql);
      }
      final row = Map<String, dynamic>.from(
        jsonDecode(
          File('assets/seed/content.json').readAsStringSync(),
        )['items'][0],
      );
      old.execute('INSERT INTO local_content VALUES(?,?,?,?,?)', [
        row['id'],
        row['category'],
        jsonEncode(row),
        null,
        1,
      ]);
      old.execute("INSERT INTO bookmarks VALUES('circulation','2026-10-01')");
      old.execute(
        "INSERT INTO reading_history VALUES('circulation','2026-10-02')",
      );
      old.execute("INSERT INTO settings VALUES('language','en')");
      old.execute(
        "INSERT INTO downloaded_packs VALUES('existing-pack',3,'/old/path','{}')",
      );
      old.execute('PRAGMA user_version=1');
      old.dispose();
      final db = LocalDatabase(NativeDatabase(file));
      expect((await db.content('circulation'))!['body_ar'], row['body_ar']);
      expect(await db.bookmarked('circulation'), isTrue);
      expect(await db.setting('language'), 'en');
      expect((await db.packs()).single['version'], 3);
      expect(
        (await db.customSelect('SELECT * FROM reading_history').get()).length,
        1,
      );
      expect((await db.provenanceFor('circulation'))!['license'], 'CC-BY-4.0');
      expect((await db.contents(search: 'الدوره')).single['id'], 'circulation');
      await db.close();
      final reopened = LocalDatabase(NativeDatabase(file));
      expect(await reopened.bookmarked('circulation'), isTrue);
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );
}
