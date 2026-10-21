import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/remote/api.dart';
import '../data/packs/pack_manager.dart';

final databaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(),
);
final rootProvider = Provider<Directory>((ref) => throw UnimplementedError());
final apiProvider = Provider<Api>((ref) => Api());
final localeProvider = StateProvider<String>((ref) => 'ar');
final themeProvider = StateProvider<bool>((ref) => false);
final scaleProvider = StateProvider<double>((ref) => 1);
final refreshProvider = StateProvider<int>((ref) => 0);
final managerProvider = ChangeNotifierProvider<PackManager>(
  (ref) => PackManager(
    ref.watch(databaseProvider),
    ref.watch(apiProvider),
    ref.watch(rootProvider),
  ),
);
