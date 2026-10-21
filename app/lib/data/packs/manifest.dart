import 'package:path/path.dart' as p;

class PackManifest {
  PackManifest(this.data) {
    if (data['schema_version'] != 1 || data['status'] != 'published') {
      throw FormatException('Incompatible/unpublished pack');
    }
    final id = data['pack_id'];
    if (id is! String || !RegExp(r'^[a-z0-9][a-z0-9-]{0,79}$').hasMatch(id)) {
      throw FormatException('Invalid pack id');
    }
    if (data['pack_version'] is! int || (data['pack_version'] as int) < 1) {
      throw FormatException('Invalid version');
    }
    final min = data['min_app_version'];
    if (min is! String || min != '0.1.0') {
      throw FormatException('Unsupported minimum app version');
    }
    if ((data['dependencies'] as List).isNotEmpty) {
      throw FormatException(
        'Dependency packs require explicit installation first',
      );
    }
    final paths = <String>{};
    var total = 0;
    if (files.isEmpty || files.length > 200) {
      throw FormatException('Invalid file count');
    }
    for (final f in files) {
      final path = f['relative_path'];
      if (path is! String ||
          path.isEmpty ||
          path.length > 200 ||
          p.posix.isAbsolute(path) ||
          path.contains('\\') ||
          path.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
          path.contains(':') ||
          !paths.add(path)) {
        throw FormatException('Unsafe/duplicate path');
      }
      final size = f['size_bytes'];
      if (size is! int || size <= 0 || size > 64 * 1024 * 1024) {
        throw FormatException('Invalid file size');
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(f['sha256'] as String? ?? '')) {
        throw FormatException('Invalid hash');
      }
      if (f['asset_id'] is! String ||
          !RegExp(r'^[a-z0-9-]+$').hasMatch(f['asset_id'])) {
        throw FormatException('Invalid asset');
      }
      total += size;
    }
    if (total != data['size_bytes'] ||
        total != data['total_uncompressed_bytes'] ||
        total > 128 * 1024 * 1024) {
      throw FormatException('Size mismatch or quota exceeded');
    }
  }
  final Map<String, dynamic> data;
  String get id => data['pack_id'];
  int get version => data['pack_version'];
  int get bytes => data['size_bytes'];
  List<Map<String, dynamic>> get files =>
      List<Map<String, dynamic>>.from(data['files']);
}
