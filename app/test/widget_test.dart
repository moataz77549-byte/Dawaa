import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dawa_hayah/app.dart';
import 'package:dawa_hayah/core/providers.dart';
import 'package:dawa_hayah/data/local/database.dart';

void main() {
  testWidgets('offline first open renders Arabic and switches to English LTR', (
    tester,
  ) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    await db.seed(json: File('assets/seed/content.json').readAsStringSync());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const DawaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('دواء وحياة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('دواء وحياة'))),
      TextDirection.rtl,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language')));
    await tester.pumpAndSettle();
    expect(find.text('Settings and storage'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Settings and storage'))),
      TextDirection.ltr,
    );
  });
}
