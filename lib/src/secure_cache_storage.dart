import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cache_compressor.dart';
import 'cache_encryptor.dart';
import 'cache_entry.dart';
import 'cache_storage.dart';

/// Wraps another [CacheStorage] and stores each entry as one compressed,
/// encrypted string.
///
/// ```dart
/// final storage = SecureCacheStorage(
///   hiveStorage,
///   encryptor: AesGcmEncryptor.fromBase64(keyFromKeystore),
///   compressor: const GZipCompressor(),
/// );
/// ```
///
/// An entry that cannot be decrypted (wrong key, tampered data, written
/// without encryption) is treated as a cache miss.
class SecureCacheStorage implements CacheStorage {
  final CacheStorage _inner;

  /// The encryptor applied after compression. Defaults to [NoOpEncryptor].
  final CacheEncryptor encryptor;

  /// The compressor applied before encryption. Defaults to [NoOpCompressor].
  final CacheCompressor compressor;

  /// Wraps [_inner].
  SecureCacheStorage(
    this._inner, {
    CacheEncryptor? encryptor,
    CacheCompressor? compressor,
  }) : encryptor = encryptor ?? const NoOpEncryptor(),
       compressor = compressor ?? const NoOpCompressor();

  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) async {
    final jsonString = jsonEncode(entry.toJson());
    final sealed = encryptor.encrypt(compressor.compress(jsonString));

    // Only the opaque blob is stored; createdAt and ttl live inside it too.
    await _inner.write(
      key,
      CacheEntry<String>(
        data: sealed,
        createdAt: entry.createdAt,
        ttl: entry.ttl,
      ),
    );
  }

  @override
  Future<CacheEntry<dynamic>?> read(String key) async {
    final secureEntry = await _inner.read(key);
    if (secureEntry == null) return null;

    try {
      final sealed = secureEntry.data as String;
      final json = jsonDecode(compressor.decompress(encryptor.decrypt(sealed)));
      return CacheEntry<dynamic>.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[cache_nexus] SecureCacheStorage could not read "$key": $e',
        );
      }
      return null;
    }
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> deleteByPrefix(String prefix) => _inner.deleteByPrefix(prefix);

  @override
  Future<void> clear() => _inner.clear();
}
