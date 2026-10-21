import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dawa_hayah/data/packs/manifest.dart';

void main() {
  Map<String, dynamic> sample() => jsonDecode(
    File(
      '../backend/storage/manifests/circulation-demo.json',
    ).readAsStringSync(),
  );
  test('accepts actual test-pack manifest', () {
    expect(PackManifest(sample()).files.length, 3);
  });
  test(
    'rejects traversal, absolute paths, duplicate paths and backslashes',
    () {
      for (final path in [
        '../secret',
        '/secret',
        'a/../../secret',
        r'a\secret',
        'a//b',
        'a/./b',
      ]) {
        final m = sample();
        m['files'][0]['relative_path'] = path;
        expect(() => PackManifest(m), throwsFormatException, reason: path);
      }
      final m = sample();
      m['files'][1]['relative_path'] = m['files'][0]['relative_path'];
      expect(() => PackManifest(m), throwsFormatException);
    },
  );
  test('rejects incompatible schema, hash, file size and total mismatch', () {
    for (final change in [
      (Map m) => m['schema_version'] = 2,
      (Map m) => m['files'][0]['sha256'] = 'bad',
      (Map m) => m['files'][0]['size_bytes'] = -1,
      (Map m) => m['size_bytes'] = 0,
      (Map m) => m['min_app_version'] = '9.0.0',
    ]) {
      final m = sample();
      change(m);
      expect(() => PackManifest(m), throwsFormatException);
    }
  });
}
