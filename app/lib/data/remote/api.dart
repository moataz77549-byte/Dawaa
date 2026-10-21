import 'dart:convert';

import 'package:http/http.dart' as http;

class Api {
  Api({http.Client? client, String? base})
    : client = client ?? http.Client(),
      base =
          base ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue:
                'https://br-noisy-poetry-bats6www-api.compute.c-8.eu-central-1.aws.neon.tech',
          );
  final http.Client client;
  final String base;
  Future<dynamic> get(String path) async {
    final uri = Uri.parse('$base$path');
    if (uri.scheme != 'https') {
      throw StateError('HTTPS required');
    }
    final r = await client.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw StateError('API ${r.statusCode}');
    }
    return jsonDecode(r.body);
  }

  Future<List<Map<String, dynamic>>> packs() async =>
      List<Map<String, dynamic>>.from((await get('/v1/packs'))['items']);
  Future<Map<String, dynamic>> manifest(String id) async =>
      Map<String, dynamic>.from(
        await get('/v1/packs/${Uri.encodeComponent(id)}/manifest'),
      );
  Future<Uri> access(String id) async {
    final r = await get('/v1/assets/${Uri.encodeComponent(id)}/access');
    final uri = Uri.parse(r['url'] as String);
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw StateError('Unsafe asset URL');
    }
    return uri;
  }
}
