import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dawa_hayah/data/local/database.dart';
import 'package:dawa_hayah/data/packs/manifest.dart';
import 'package:dawa_hayah/data/packs/pack_manager.dart';
import 'package:dawa_hayah/data/remote/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late Directory dir;
  late Map<String, List<int>> bytes;
  var broken = false;
  var calls = 0;
  late Api api;
  PackManifest manifest([int version = 1]) {
    final base =
        jsonDecode(
              File(
                '../backend/storage/manifests/circulation-demo.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    base['pack_version'] = version;
    base['files'] = [
      for (final e in bytes.entries)
        {
          'relative_path': e.key,
          'object_key': 'test/${e.key}',
          'asset_id': 'test-${e.key.replaceAll('.', '-')}',
          'mime_type': 'application/octet-stream',
          'size_bytes': e.value.length,
          'sha256': sha256.convert(e.value).toString(),
        },
    ];
    base['size_bytes'] = base['total_uncompressed_bytes'] = bytes.values
        .fold<int>(0, (n, b) => n + b.length);
    return PackManifest(base);
  }

  PackManager manager({int free = 1 << 40}) => PackManager(
    db,
    api,
    dir,
    networkAllowed: () async => true,
    freeBytes: () async => free,
  );
  setUp(() async {
    db = LocalDatabase.memory();
    dir = await Directory.systemTemp.createTemp('dawa-test-');
    await db.seed(json: File('assets/seed/content.json').readAsStringSync());
    final row = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/seed/content.json').readAsStringSync(),
      )['items'][0],
    );
    row['id'] = 'cloud-circulation';
    bytes = {
      'content.json': utf8.encode(
        jsonEncode({
          'version': 1,
          'items': [row],
        }),
      ),
      'diagram.png': File('assets/seed/demo.png').readAsBytesSync(),
      'demo.glb': File('assets/models/sample/demo.glb').readAsBytesSync(),
    };
    broken = false;
    calls = 0;
    api = Api(
      base: 'https://api.example',
      client: MockClient((req) async {
        calls++;
        if (req.url.host == 'api.example') {
          final id = req.url.pathSegments[2];
          final file = bytes.keys.firstWhere(
            (f) => 'test-${f.replaceAll('.', '-')}' == id,
          );
          return http.Response(
            jsonEncode({'url': 'https://objects.example/$file'}),
            200,
          );
        }
        return http.Response.bytes(
          broken ? [0, 1, 2] : bytes[req.url.pathSegments.last]!,
          200,
        );
      }),
    );
  });
  tearDown(() async {
    api.client.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'verified install, offline read, deletion preserve builtins and bookmarks',
    () async {
      final m = manager();
      await m.install(manifest());
      expect(m.status, 'complete');
      api.client.close();
      final pack = (await db.packs()).single;
      expect((await db.content('cloud-circulation'))!['body_ar'], isNotEmpty);
      expect(await File('${pack['directory']}/demo.glb').exists(), isTrue);
      await db.bookmark('cloud-circulation');
      await db.bookmark('circulation');
      await m.remove('circulation-demo');
      expect(await db.packs(), isEmpty);
      expect(await db.content('cloud-circulation'), isNull);
      expect(await db.bookmarked('cloud-circulation'), isTrue);
      expect(await db.bookmarked('circulation'), isTrue);
      expect((await db.contents()).length, 12);
    },
  );
  test('corrupt update keeps previous immutable version and data', () async {
    final m = manager();
    await m.install(manifest());
    final old = (await db.packs()).single;
    broken = true;
    await m.install(manifest(2));
    expect(m.status, 'failed');
    expect((await db.packs()).single['version'], 1);
    expect(await File('${old['directory']}/demo.glb').exists(), isTrue);
    expect(await db.content('cloud-circulation'), isNotNull);
  });
  test('pause and file resume rehash completed files', () async {
    final m = manager();
    var paused = false;
    void pause() {
      if (!paused && m.received > 0) {
        paused = true;
        m.pause();
      }
    }

    m.addListener(pause);
    await m.install(manifest());
    expect(m.status, 'paused');
    expect(await db.packs(), isEmpty);
    m.removeListener(pause);
    final before = calls;
    await m.install(manifest());
    expect(m.status, 'complete');
    expect(calls - before, 4);
  });
  test('cancel discards staging and leaves no index', () async {
    final m = manager();
    void cancel() {
      if (m.received > 0) m.cancel();
    }

    m.addListener(cancel);
    await m.install(manifest());
    expect(m.status, 'cancelled');
    expect(await db.packs(), isEmpty);
    expect(
      await Directory('${dir.path}/staging/circulation-demo-1').exists(),
      isFalse,
    );
  });
  test('low disk rejects before transferring bytes', () async {
    final m = manager(free: 0);
    await m.install(manifest());
    expect(m.status, 'failed');
    expect(calls, 0);
    expect(await db.packs(), isEmpty);
  });
}
