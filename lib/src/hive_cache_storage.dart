import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'cache_entry.dart';
import 'cache_storage.dart';
import 'type_registry.dart';

/// A persistent [CacheStorage] backed by a Hive box (Hive CE).
///
/// Values are stored as JSON-like maps, so they survive app restarts.
/// Custom classes need a `CacheAdapter` registered on the manager to be
/// rebuilt after a restart.
///
/// Hive limits keys to 255 UTF-8 bytes. Longer keys (long URLs, many
/// non-Latin characters) are stored under a SHA-256 based key automatically;
/// the original key is kept with the value so prefix deletes still work.
class HiveCacheStorage implements CacheStorage {
  /// The name of the Hive box.
  final String boxName;
  Box<dynamic>? _box;

  static const String _hashedPrefix = 'cn#';
  static const int _maxKeyBytes = 255;

  /// Creates a storage for [boxName]. Call [init] before use.
  HiveCacheStorage({this.boxName = 'cache_nexus'});

  /// Opens the box.
  ///
  /// With [initHive] (the default) `Hive.initFlutter()` is called first.
  /// Pass `false` when your app already initialised Hive CE itself. If Hive
  /// turns out not to be initialised, `Hive.initFlutter()` is called anyway
  /// and a debug message explains why.
  Future<void> init({bool initHive = true}) async {
    if (initHive) {
      await Hive.initFlutter();
    }
    try {
      _box = await Hive.openBox<dynamic>(boxName);
    } on HiveError catch (e) {
      if (initHive || !e.message.contains('initialize')) rethrow;
      debugPrint(
        '[cache_nexus] Hive CE was not initialised (did you call '
        'Hive.init from package:hive instead of package:hive_ce?). '
        'Calling Hive.initFlutter() for box "$boxName".',
      );
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(boxName);
    }
  }

  /// Whether [init] has completed and the box is open.
  bool get isInitialized => _box?.isOpen ?? false;

  /// The underlying box. Throws if [init] has not been called.
  Box<dynamic> get box {
    final b = _box;
    if (b == null) {
      throw Exception('HiveCacheStorage not initialized. Call init() first.');
    }
    return b;
  }

  /// The key used inside Hive for the cache key [key].
  @visibleForTesting
  static String storageKeyFor(String key) {
    if (utf8.encode(key).length <= _maxKeyBytes &&
        !key.startsWith(_hashedPrefix)) {
      return key;
    }
    return '$_hashedPrefix${sha256.convert(utf8.encode(key))}';
  }

  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) async {
    final storageKey = storageKeyFor(key);
    final json = entry.toJson();
    if (storageKey != key) json['key'] = key;
    await box.put(storageKey, json);
  }

  @override
  Future<CacheEntry<dynamic>?> read(String key) async {
    final storageKey = storageKeyFor(key);
    final raw = box.get(storageKey);
    if (raw == null) return null;

    try {
      final json = CacheTypeRegistry.normalize(raw) as Map<String, dynamic>;
      if (storageKey != key && json['key'] != key) return null;
      final ttl = json['ttl'];
      return CacheEntry<dynamic>(
        data: json['data'],
        createdAt: DateTime.parse(json['createdAt'] as String),
        ttl: ttl != null ? Duration(milliseconds: (ttl as num).toInt()) : null,
      );
    } catch (e) {
      // Unreadable row (e.g. written by something else): drop it.
      await box.delete(storageKey);
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    await box.delete(storageKeyFor(key));
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    final keysToDelete = <dynamic>[];
    for (final k in box.keys) {
      final s = k.toString();
      if (s.startsWith(_hashedPrefix)) {
        final value = box.get(k);
        final original = value is Map ? value['key'] : null;
        if (original is String && original.startsWith(prefix)) {
          keysToDelete.add(k);
        }
      } else if (s.startsWith(prefix)) {
        keysToDelete.add(k);
      }
    }
    await box.deleteAll(keysToDelete);
  }

  @override
  Future<void> clear() async {
    await box.clear();
  }

  /// Closes the box. Call [init] again to reopen it.
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
