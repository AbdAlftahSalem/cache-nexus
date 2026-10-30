import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache_entry.dart';
import 'cache_event.dart';
import 'cache_exceptions.dart';
import 'cache_policy.dart';
import 'cache_storage.dart';
import 'network_status.dart';
import 'observability_manager.dart';
import 'type_registry.dart';

/// The result of looking a key up in the memory and persistent tiers.
class _Lookup<T> {
  const _Lookup.miss() : found = false, value = null, entry = null, error = null;
  const _Lookup.hit(this.value, CacheEntry<dynamic> this.entry)
    : found = true,
      error = null;
  const _Lookup.undecodable(this.entry, Object this.error)
    : found = false,
      value = null;

  final bool found;
  final T? value;
  final CacheEntry<dynamic>? entry;
  final Object? error;

  bool get isExpired => entry?.isExpired ?? false;
}

/// Implements the five [CachePolicy] strategies on top of a memory tier and an
/// optional persistent tier.
///
/// `CacheNexusManager` creates and drives one; you only need this class when
/// building your own manager.
class PolicyResolver {
  final ObservabilityManager _observability;
  final CacheStorage _memoryStorage;
  final CacheStorage? _persistentStorage;
  final Map<String, Future<dynamic>> _inFlightRequests = {};
  final CacheTypeRegistry _registry;
  final String? Function(String resolvedKey)? _legacyKeyOf;
  final Set<String> _warned = {};

  /// Creates a resolver.
  ///
  /// [adapters] is kept for 1.0 compatibility; prefer passing a [registry].
  /// [legacyKeyOf] maps a key to the key an older version stored the same
  /// value under; such entries are migrated on first read.
  PolicyResolver({
    required ObservabilityManager observability,
    required CacheStorage memoryStorage,
    CacheStorage? persistentStorage,
    Map<Type, dynamic> adapters = const {},
    CacheTypeRegistry? registry,
    String? Function(String resolvedKey)? legacyKeyOf,
  }) : _observability = observability,
       _memoryStorage = memoryStorage,
       _persistentStorage = persistentStorage,
       _registry =
           registry ??
           CacheTypeRegistry(adapters.isEmpty ? <Type, dynamic>{} : adapters),
       _legacyKeyOf = legacyKeyOf;

  /// Converts cached [data] to `T`, using registered adapters and the built-in
  /// collection decoders. Returns `null` when that is not possible.
  T? tryCast<T>(dynamic data) {
    final result = _registry.decode<T>(data);
    return result.ok ? result.value : null;
  }

  /// Resolves [resolvedKey] according to [policy].
  ///
  /// [onStore] persists a freshly fetched value; [onNotify] is called after a
  /// successful fetch and store.
  Future<T> resolve<T>({
    required String resolvedKey,
    required Future<T> Function() fetcher,
    Duration? ttl,
    required CachePolicy policy,
    required Future<void> Function(String key, T data, Duration? ttl) onStore,
    required Future<void> Function(String key, dynamic data) onNotify,
  }) async {
    switch (policy) {
      case CachePolicy.cacheFirst:
        return _cacheFirst<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
      case CachePolicy.networkFirst:
        return _networkFirst<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
      case CachePolicy.cacheOnly:
        return _readFromCache<T>(resolvedKey);
      case CachePolicy.networkOnly:
        return _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
      case CachePolicy.staleWhileRevalidate:
        return _staleWhileRevalidate<T>(
          resolvedKey,
          fetcher,
          ttl,
          onStore,
          onNotify,
        );
    }
  }

  /// Reads [resolvedKey] from memory, then from persistent storage (promoting
  /// a persistent hit into memory). Expired entries are returned too; the
  /// caller decides what to do with them.
  Future<_Lookup<T>> _lookup<T>(String resolvedKey) async {
    final memEntry = await _safeRead(_memoryStorage, resolvedKey);
    if (memEntry != null) {
      final decoded = _registry.decode<T>(memEntry.data);
      if (decoded.ok) return _Lookup<T>.hit(decoded.value, memEntry);
    }

    final persistent = _persistentStorage;
    if (persistent == null) return const _Lookup.miss();

    var entry = await _safeRead(persistent, resolvedKey);
    if (entry == null) {
      entry = await _migrateLegacy(persistent, resolvedKey);
      if (entry == null) return const _Lookup.miss();
    }

    final decoded = _registry.decode<T>(entry.data);
    if (!decoded.ok) {
      final error = CacheDecodeException(
        key: resolvedKey,
        requestedType: '$T',
        storedType: '${entry.data.runtimeType}',
        cause: decoded.error,
      );
      _reportDecodeError(resolvedKey, error);
      return _Lookup<T>.undecodable(entry, error);
    }

    final promoted = CacheEntry<dynamic>(
      data: decoded.value,
      createdAt: entry.createdAt,
      ttl: entry.ttl,
    );
    try {
      await _memoryStorage.write(resolvedKey, promoted);
    } catch (_) {
      // A memory write failure only costs a later disk read.
    }
    return _Lookup<T>.hit(decoded.value, promoted);
  }

  Future<CacheEntry<dynamic>?> _safeRead(
    CacheStorage storage,
    String key,
  ) async {
    try {
      return await storage.read(key);
    } catch (e) {
      _observability.emit(CacheEventType.error, key, error: e);
      return null;
    }
  }

  Future<CacheEntry<dynamic>?> _migrateLegacy(
    CacheStorage persistent,
    String resolvedKey,
  ) async {
    final legacyKey = _legacyKeyOf?.call(resolvedKey);
    if (legacyKey == null || legacyKey == resolvedKey) return null;
    final legacy = await _safeRead(persistent, legacyKey);
    if (legacy == null) return null;
    try {
      await persistent.write(resolvedKey, legacy);
      await persistent.delete(legacyKey);
    } catch (e) {
      _observability.emit(CacheEventType.error, resolvedKey, error: e);
    }
    return legacy;
  }

  void _reportDecodeError(String key, CacheDecodeException error) {
    _observability.emit(CacheEventType.error, key, error: error);
    if (kDebugMode && _warned.add('$key|${error.requestedType}')) {
      debugPrint('[cache_nexus] $error');
    }
  }

  void _emitHit(String key, Object? data) =>
      _observability.emit(CacheEventType.hit, key, data: data);

  Future<T> _cacheFirst<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    final lookup = await _lookup<T>(resolvedKey);
    if (lookup.found) {
      if (!lookup.isExpired) {
        _emitHit(resolvedKey, lookup.value);
        return lookup.value as T;
      }
      _observability.emit(CacheEventType.expired, resolvedKey);
    }
    _observability.emit(CacheEventType.miss, resolvedKey);
    return _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
  }

  Future<T> _networkFirst<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    if (!await NetworkStatus.isOnline) {
      return _readFromCache<T>(resolvedKey);
    }
    try {
      return await _performFetch<T>(
        resolvedKey,
        fetcher,
        ttl,
        onStore,
        onNotify,
      );
    } catch (networkError, stackTrace) {
      final lookup = await _lookup<T>(resolvedKey);
      if (lookup.found && !lookup.isExpired) {
        _emitHit(resolvedKey, lookup.value);
        return lookup.value as T;
      }
      // Nothing usable in the cache: surface the real network error.
      Error.throwWithStackTrace(networkError, stackTrace);
    }
  }

  Future<T> _readFromCache<T>(String resolvedKey) async {
    final lookup = await _lookup<T>(resolvedKey);
    if (lookup.found) {
      if (!lookup.isExpired) {
        _emitHit(resolvedKey, lookup.value);
        return lookup.value as T;
      }
      _observability.emit(CacheEventType.expired, resolvedKey);
    }
    _observability.emit(CacheEventType.miss, resolvedKey);
    final error = lookup.error;
    if (error is CacheDecodeException) throw error;
    if (null is T) return null as T;
    throw CacheMissException(resolvedKey);
  }

  Future<T> _performFetch<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    final inFlight = _inFlightRequests[resolvedKey];
    if (inFlight != null) {
      final shared = _registry.decode<T>(await inFlight);
      if (shared.ok) return shared.value as T;
      // Same key requested with an incompatible type: fetch independently.
    }

    final stopwatch = Stopwatch()..start();
    final future = Future<T>.sync(fetcher);
    if (inFlight == null) _inFlightRequests[resolvedKey] = future;

    try {
      final result = await future;

      if (result == null && null is! T) {
        throw Exception(
          'Fetcher returned null result for non-nullable type $T for key: '
          '$resolvedKey',
        );
      }

      _observability.emit(
        CacheEventType.fetch,
        resolvedKey,
        data: result,
        duration: stopwatch.elapsed,
      );
      try {
        await onStore(resolvedKey, result, ttl);
      } catch (e) {
        // The data was fetched successfully; a failing cache write must not
        // turn that into an error for the caller.
        _observability.emit(CacheEventType.error, resolvedKey, error: e);
      }
      await onNotify(resolvedKey, result);
      return result;
    } catch (e) {
      _observability.emit(
        CacheEventType.error,
        resolvedKey,
        error: e,
        duration: stopwatch.elapsed,
      );
      rethrow;
    } finally {
      stopwatch.stop();
      if (identical(_inFlightRequests[resolvedKey], future)) {
        _inFlightRequests.remove(resolvedKey);
      }
    }
  }

  Future<T> _staleWhileRevalidate<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    final lookup = await _lookup<T>(resolvedKey);
    if (lookup.found) {
      if (lookup.isExpired) {
        _observability.emit(CacheEventType.expired, resolvedKey);
      }
      _emitHit(resolvedKey, lookup.value);
      unawaited(_revalidate<T>(resolvedKey, fetcher, ttl, onStore, onNotify));
      return lookup.value as T;
    }
    _observability.emit(CacheEventType.miss, resolvedKey);
    return _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
  }

  Future<void> _revalidate<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    try {
      if (!await NetworkStatus.isOnline) return;
      await _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
    } catch (_) {
      // Background refresh failures are reported as error events by
      // _performFetch; the caller already has the cached value.
    }
  }
}
