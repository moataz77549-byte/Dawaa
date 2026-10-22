import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;

import '../local/database.dart';
import '../remote/api.dart';
import 'manifest.dart';

class DownloadStopped implements Exception {}

class PackManager extends ChangeNotifier {
  PackManager(
    this.db,
    this.api,
    this.root, {
    this.networkAllowed,
    this.freeBytes,
  });
  final Future<bool> Function()? networkAllowed;
  final Future<int> Function()? freeBytes;
  Future<bool> _network() async {
    if (await db.setting('wifi_only') == 'false') {
      return true;
    }
    final connections = await Connectivity().checkConnectivity();
    return connections.contains(ConnectivityResult.wifi) ||
        connections.contains(ConnectivityResult.ethernet);
  }

  Future<int> _space() async =>
      await const MethodChannel(
        'ye.moataz.dawa/storage',
      ).invokeMethod<int>('availableBytes') ??
      0;
  final LocalDatabase db;
  final Api api;
  final Directory root;
  String? active;
  bool stopped = false;
  bool cancelRequested = false;
  int received = 0, total = 0;
  String status = 'idle';
  String? error;
  void pause() {
    stopped = true;
  }

  void cancel() {
    cancelRequested = true;
    stopped = true;
  }

  Future<void> _state(String id, String s, {String? message}) async {
    status = s;
    error = message;
    await db.job(id, s, received, total, error: message);
    notifyListeners();
  }

  Future<void> install(PackManifest manifest) async {
    if (active != null) {
      throw StateError('One download at a time');
    }
    active = manifest.id;
    stopped = false;
    cancelRequested = false;
    received = 0;
    total = manifest.bytes;
    final dir = Directory(
      p.join(root.path, 'staging', '${manifest.id}-${manifest.version}'),
    );
    final installed = Directory(
      p.join(root.path, 'installed', '${manifest.id}-${manifest.version}'),
    );
    try {
      if (!await (networkAllowed ?? _network)()) {
        throw StateError('Wi-Fi required by settings');
      }
      if (await (freeBytes ?? _space)() < manifest.bytes + 16 * 1024 * 1024) {
        throw FileSystemException('Insufficient free storage');
      }
      final prior = await db.packs();
      if (prior.any(
        (x) => x['id'] == manifest.id && x['version'] == manifest.version,
      )) {
        throw StateError('Version already installed');
      }
      await dir.create(recursive: true);
      await _state(manifest.id, 'downloading');
      for (final f in manifest.files) {
        if (stopped) {
          throw DownloadStopped();
        }
        final file = File(p.join(dir.path, f['relative_path']));
        await file.parent.create(recursive: true);
        // File-level resume: completed files are rehashed; partial file starts again.
        if (await file.exists() &&
            await file.length() == f['size_bytes'] &&
            await sha256
                    .bind(file.openRead())
                    .first
                    .then((d) => d.toString()) ==
                f['sha256']) {
          received += f['size_bytes'] as int;
          notifyListeners();
          continue;
        }
        var success = false;
        for (var attempt = 0; attempt < 3 && !success; attempt++) {
          final start = received;
          try {
            final url = await api.access(
              f['asset_id'],
            ); // renew expired URL each attempt
            final req = http.Request('GET', url)..followRedirects = false;
            final response = await api.client
                .send(req)
                .timeout(const Duration(seconds: 20));
            if (response.statusCode != 200) {
              await response.stream.drain<void>();
              throw HttpException('Storage ${response.statusCode}');
            }
            final temp = File('${file.path}.part');
            final sink = temp.openWrite();
            var size = 0;
            try {
              await for (final chunk in response.stream.timeout(
                const Duration(seconds: 30),
              )) {
                if (stopped) {
                  throw DownloadStopped();
                }
                size += chunk.length;
                if (size > (f['size_bytes'] as int)) {
                  throw FormatException('Oversized file');
                }
                sink.add(chunk);
                received = start + size;
                notifyListeners();
              }
            } finally {
              await sink.close();
            }
            if (size != f['size_bytes'] ||
                await sha256
                        .bind(temp.openRead())
                        .first
                        .then((d) => d.toString()) !=
                    f['sha256']) {
              throw FormatException('Checksum or size mismatch');
            }
            await temp.rename(file.path);
            success = true;
          } on DownloadStopped {
            rethrow;
          } catch (e) {
            received = start;
            if (attempt == 2) {
              rethrow;
            }
            await Future<void>.delayed(Duration(seconds: 1 << attempt));
          }
        }
      }
      if (stopped) {
        throw DownloadStopped();
      }
      final data =
          jsonDecode(
                await File(p.join(dir.path, 'content.json')).readAsString(),
              )
              as Map<String, dynamic>;
      if (data['version'] != 1 || data['items'] is! List) {
        throw FormatException('Invalid content schema');
      }
      final contentIds = <String>{};
      for (final item in data['items']) {
        final x = Map<String, dynamic>.from(item);
        if (!contentIds.add(x['id'] as String? ?? '') ||
            x['status'] != 'published' ||
            x['clinical'] != false ||
            x['license'] != 'CC-BY-4.0' ||
            x['id'] is! String ||
            !RegExp(r'^[a-z0-9-]+$').hasMatch(x['id'])) {
          throw FormatException('Unlicensed or clinical content');
        }
        if (x['canonical_concept_id'] != null) {
          final provenance = x['provenance'];
          if (provenance is! Map ||
              provenance['offline_metadata_allowed'] != true ||
              provenance['content_class'] != 'identity_metadata' ||
              provenance['source_id'] != x['source_id'] ||
              provenance['license'] is! String ||
              !RegExp(
                r'^[a-f0-9]{64}$',
              ).hasMatch(provenance['payload_hash'] as String? ?? '')) {
            throw FormatException(
              'Metadata reuse permission or provenance missing',
            );
          }
        }
        for (final key in [
          'title_ar',
          'title_en',
          'body_ar',
          'body_en',
          'category',
          'source_url',
          'attribution',
        ]) {
          if (x[key] is! String) {
            throw FormatException('Missing content field');
          }
        }
        if ((await db.content(x['id'])) != null) {
          final row = await db
              .customSelect(
                'SELECT pack_id FROM local_content WHERE id=?',
                variables: [Variable(x['id'] as String)],
              )
              .getSingle();
          if (row.data['pack_id'] != manifest.id) {
            throw FormatException('Content ownership conflict');
          }
        }
      }
      await _state(manifest.id, 'installing');
      await installed.parent.create(recursive: true);
      if (await installed.exists()) {
        await installed.delete(recursive: true);
      } // unreachable orphan only; active versions rejected above
      await dir.rename(installed.path);
      try {
        await db.transaction(() async {
          await db.customStatement(
            'DELETE FROM local_translations WHERE content_id IN (SELECT id FROM local_content WHERE pack_id=?)',
            [manifest.id],
          );
          await db.customStatement(
            'DELETE FROM local_index WHERE content_id IN (SELECT id FROM local_content WHERE pack_id=?)',
            [manifest.id],
          );
          await db.customStatement(
            'DELETE FROM local_content WHERE pack_id=?',
            [manifest.id],
          );
          for (final x in data['items']) {
            await db.putContent(
              Map<String, dynamic>.from(x),
              packId: manifest.id,
            );
          }
          await db.customStatement(
            'INSERT OR REPLACE INTO downloaded_packs VALUES(?,?,?,?)',
            [
              manifest.id,
              manifest.version,
              installed.path,
              jsonEncode(manifest.data),
            ],
          );
          await db.customStatement('DELETE FROM pack_files WHERE pack_id=?', [
            manifest.id,
          ]);
          await db.customStatement(
            'DELETE FROM local_asset_links WHERE pack_id=?',
            [manifest.id],
          );
          for (final f in manifest.files) {
            await db.customStatement('INSERT INTO pack_files VALUES(?,?,?,?)', [
              manifest.id,
              f['relative_path'],
              f['sha256'],
              f['size_bytes'],
            ]);
            await db.customStatement(
              'INSERT INTO local_asset_links VALUES(?,?)',
              [manifest.id, f['relative_path']],
            );
          }
        });
      } catch (e) {
        await installed.delete(recursive: true);
        rethrow;
      }
      // Only after pointer transaction succeeds may the previous immutable version be removed.
      for (final old in prior.where(
        (x) => x['id'] == manifest.id && x['version'] != manifest.version,
      )) {
        final d = Directory(old['directory'] as String);
        if (await d.exists()) {
          await d.delete(recursive: true);
        }
      }
      await _state(manifest.id, 'complete');
    } on DownloadStopped {
      if (cancelRequested && await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await _state(manifest.id, cancelRequested ? 'cancelled' : 'paused');
    } catch (e) {
      final text = e.toString();
      final code = text.contains('Insufficient free')
          ? 'storage_low'
          : text.contains('Wi-Fi required')
          ? 'wifi_required'
          : text.contains('Checksum') || text.contains('Oversized')
          ? 'integrity_failed'
          : text.contains('already installed')
          ? 'already_installed'
          : e is SocketException || e is TimeoutException || e is HttpException
          ? 'network_failed'
          : 'install_failed';
      await _state(manifest.id, 'failed', message: code);
    } finally {
      active = null;
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    if (active == id) {
      throw StateError('Pause active download first');
    }
    final packs = await db.packs();
    for (final pack in packs.where((x) => x['id'] == id)) {
      await db.transaction(() async {
        await db.customStatement(
          'DELETE FROM local_translations WHERE content_id IN (SELECT id FROM local_content WHERE pack_id=?)',
          [id],
        );
        await db.customStatement(
          'DELETE FROM local_index WHERE content_id IN (SELECT id FROM local_content WHERE pack_id=?)',
          [id],
        );
        for (final t in ['local_content', 'pack_files', 'local_asset_links']) {
          await db.customStatement('DELETE FROM $t WHERE pack_id=?', [id]);
        }
        await db.customStatement('DELETE FROM downloaded_packs WHERE id=?', [
          id,
        ]);
      });
      final dir = Directory(pack['directory'] as String);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    notifyListeners();
  }
}
