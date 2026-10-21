import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';

String normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670ـ]'), '');

class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);
  factory LocalDatabase.memory() => LocalDatabase(NativeDatabase.memory());
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final sql in schema) {
        await customStatement(sql);
      }
    },
    beforeOpen: (d) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
  static const schema = [
    'CREATE TABLE local_content(id TEXT PRIMARY KEY, category TEXT NOT NULL, data TEXT NOT NULL, pack_id TEXT, revision INTEGER NOT NULL)',
    'CREATE TABLE local_translations(content_id TEXT, locale TEXT, title TEXT, body TEXT, PRIMARY KEY(content_id,locale))',
    'CREATE TABLE local_index(content_id TEXT PRIMARY KEY, normalized TEXT NOT NULL)',
    'CREATE TABLE downloaded_packs(id TEXT PRIMARY KEY, version INTEGER NOT NULL, directory TEXT NOT NULL, manifest TEXT NOT NULL)',
    'CREATE TABLE pack_files(pack_id TEXT, relative_path TEXT, sha256 TEXT, bytes INTEGER, PRIMARY KEY(pack_id,relative_path))',
    'CREATE TABLE download_jobs(id TEXT PRIMARY KEY, status TEXT NOT NULL, received INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0, error TEXT)',
    'CREATE TABLE bookmarks(content_id TEXT PRIMARY KEY, created_at TEXT NOT NULL)',
    'CREATE TABLE reading_history(content_id TEXT PRIMARY KEY, read_at TEXT NOT NULL)',
    'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE TABLE local_asset_links(pack_id TEXT, path TEXT, PRIMARY KEY(pack_id,path))',
  ];
  Future<void> seed({String? json}) async {
    final data =
        jsonDecode(
              json ?? await rootBundle.loadString('assets/seed/content.json'),
            )
            as Map<String, dynamic>;
    await transaction(() async {
      for (final x in data['items'] as List) {
        await putContent(Map<String, dynamic>.from(x), seedOnly: true);
      }
      await setSetting('seed_version', '${data['version']}');
    });
  }

  Future<void> putContent(
    Map<String, dynamic> x, {
    String? packId,
    bool seedOnly = false,
  }) async {
    if (seedOnly) {
      final existing = await customSelect(
        'SELECT pack_id,revision FROM local_content WHERE id=?',
        variables: [Variable(x['id'] as String)],
      ).getSingleOrNull();
      if (existing != null &&
          (existing.data['pack_id'] != null ||
              existing.read<int>('revision') >= (x['revision'] as int))) {
        return;
      }
    }
    await customStatement(
      'INSERT OR REPLACE INTO local_content VALUES(?,?,?,?,?)',
      [x['id'], x['category'], jsonEncode(x), packId, x['revision']],
    );
    for (final lang in ['ar', 'en']) {
      await customStatement(
        'INSERT OR REPLACE INTO local_translations VALUES(?,?,?,?)',
        [x['id'], lang, x['title_$lang'], x['body_$lang']],
      );
    }
    await customStatement('INSERT OR REPLACE INTO local_index VALUES(?,?)', [
      x['id'],
      normalize(
        '${x['title_ar']} ${x['title_en']} ${x['body_ar']} ${x['body_en']}',
      ),
    ]);
  }

  Future<List<Map<String, dynamic>>> contents({
    String? category,
    String search = '',
    bool favorites = false,
  }) async {
    final rows = await customSelect(
      'SELECT c.data FROM local_content c JOIN local_index i ON i.content_id=c.id WHERE (? IS NULL OR c.category=?) AND instr(i.normalized,?)>0 ${favorites ? 'AND c.id IN (SELECT content_id FROM bookmarks)' : ''} ORDER BY c.id',
      variables: [
        Variable(category),
        Variable(category),
        Variable(normalize(search)),
      ],
    ).get();
    return rows
        .map((r) => jsonDecode(r.read<String>('data')) as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>?> content(String id) async {
    final row = await customSelect(
      'SELECT data FROM local_content WHERE id=?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    return row == null
        ? null
        : jsonDecode(row.read<String>('data')) as Map<String, dynamic>;
  }

  Future<void> bookmark(String id) async {
    final exists = await customSelect(
      'SELECT 1 FROM bookmarks WHERE content_id=?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    if (exists == null) {
      await customStatement('INSERT INTO bookmarks VALUES(?,?)', [
        id,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } else {
      await customStatement('DELETE FROM bookmarks WHERE content_id=?', [id]);
    }
  }

  Future<bool> bookmarked(String id) async =>
      (await customSelect(
        'SELECT 1 FROM bookmarks WHERE content_id=?',
        variables: [Variable(id)],
      ).getSingleOrNull()) !=
      null;
  Future<void> recordRead(String id) => customStatement(
    'INSERT OR REPLACE INTO reading_history VALUES(?,?)',
    [id, DateTime.now().toUtc().toIso8601String()],
  );
  Future<void> setSetting(String key, String value) => customStatement(
    'INSERT OR REPLACE INTO settings VALUES(?,?)',
    [key, value],
  );
  Future<String?> setting(String key) async => (await customSelect(
    'SELECT value FROM settings WHERE key=?',
    variables: [Variable(key)],
  ).getSingleOrNull())?.read<String>('value');
  Future<List<Map<String, dynamic>>> packs() async => (await customSelect(
    'SELECT * FROM downloaded_packs',
  ).get()).map((r) => r.data).toList();
  Future<List<Map<String, dynamic>>> jobs() async => (await customSelect(
    'SELECT * FROM download_jobs',
  ).get()).map((r) => r.data).toList();
  Future<void> job(
    String id,
    String status,
    int received,
    int total, {
    String? error,
  }) => customStatement(
    'INSERT OR REPLACE INTO download_jobs VALUES(?,?,?,?,?)',
    [id, status, received, total, error],
  );
  Future<void> recoverJobs() => customStatement(
    "UPDATE download_jobs SET status='paused' WHERE status IN ('downloading','installing')",
  );
}
