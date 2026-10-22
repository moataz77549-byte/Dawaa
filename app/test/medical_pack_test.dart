import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dawa_hayah/data/local/database.dart';
import 'package:dawa_hayah/data/packs/manifest.dart';
import 'package:dawa_hayah/data/packs/pack_manager.dart';
import 'package:dawa_hayah/data/remote/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'metadata pack reads offline and removal preserves personal data',
    () async {
      final root = await Directory.systemTemp.createTemp('medical-pack-');
      final db = LocalDatabase.memory();
      final bytes = File(
        '../backend/storage/packs/medical-identities/1/content.json',
      ).readAsBytesSync();
      final manifest = PackManifest(
        jsonDecode(
          File(
            '../backend/storage/manifests/medical-identities.json',
          ).readAsStringSync(),
        ),
      );
      final api = Api(
        base: 'https://api.example',
        client: MockClient(
          (r) async => r.url.host == 'api.example'
              ? http.Response(
                  '{"url":"https://storage.example/content.json"}',
                  200,
                )
              : http.Response.bytes(bytes, 200),
        ),
      );
      final manager = PackManager(
        db,
        api,
        root,
        networkAllowed: () async => true,
        freeBytes: () async => 1 << 30,
      );
      await db.seed(json: File('assets/seed/content.json').readAsStringSync());
      await manager.install(manifest);
      expect(manager.status, 'complete', reason: manager.error);
      api.client.close();
      final row = (await db.contents(search: 'RxCUI:161')).single;
      expect(row['clinical'], false);
      expect(row['body_ar'], contains('مسودة'));
      expect(
        (await db.provenanceFor(row['id']))!['offline_metadata_allowed'],
        true,
      );
      await db.bookmark(row['id']);
      await manager.remove(manifest.id);
      expect(await db.content(row['id']), isNull);
      expect(await db.bookmarked(row['id']), true);
      expect((await db.contents()).length, 14);
      await db.close();
      await root.delete(recursive: true);
    },
  );
  test('future application and local schemas are rejected', () {
    final m =
        jsonDecode(
              File(
                '../backend/storage/manifests/medical-identities.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      () => PackManifest({...m, 'min_app_version': '0.3.0'}),
      throwsFormatException,
    );
    expect(
      () => PackManifest({...m, 'min_local_schema': 3}),
      throwsFormatException,
    );
  });
}
