import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'core/providers.dart';
import 'data/local/database.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await getApplicationSupportDirectory();
  final db = LocalDatabase(
    NativeDatabase.createInBackground(File(p.join(root.path, 'dawa.sqlite'))),
  );
  await db.seed();
  await db.recoverJobs();
  final lang = await db.setting('language') ?? 'ar';
  final dark = await db.setting('dark') == 'true';
  final scale = double.tryParse(await db.setting('scale') ?? '1') ?? 1;
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        rootProvider.overrideWithValue(root),
        localeProvider.overrideWith((ref) => lang),
        themeProvider.overrideWith((ref) => dark),
        scaleProvider.overrideWith((ref) => scale),
      ],
      child: const DawaApp(),
    ),
  );
}
