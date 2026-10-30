import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache_adapter.dart';
import 'cache_entry.dart';
import 'cache_exceptions.dart';
import 'cache_storage.dart';
import 'memory_cache_storage.dart';
import 'cache_policy.dart';
import 'cache_event.dart';
import 'cache_stats.dart';
import 'sync_task.dart';
import 'sync_engine.dart';
import 'cache_context.dart';
import 'observability_manager.dart';
import 'policy_resolver.dart';
import 'reactive_engine.dart';
import 'cache_nexus_mode.dart';
import 'type_registry.dart';

/// The entry point of cache_nexus: a two-tier (memory + persistent) cache
/// with TTLs, cache policies, per-user isolation, reactive streams, an
/// optional offline sync queue and dev-mode observability.
///
/// ```dart
/// final storage = HiveCacheStorage();
/// await storage.init();
/// final cache = CacheNexusManager(persistentStorage: storage);
///
/// final posts = await cache.get<List<Post>>(
///   key: 'posts',
///   fetcher: api.fetchPosts,
///   ttl: const Duration(minutes: 5),
///   policy: CachePolicy.staleWhileRevalidate,
/// );
/// ```
class CacheNexusManager {
  /// The fast, in-process tier. Defaults to [MemoryCacheStorage].
  final CacheStorage memoryStorage;

  /// The tier that survives restarts (e.g. [HiveCacheStorage]), if any.
  final CacheStorage? persistentStorage;

  /// The offline write queue used by [enqueueSyncTask], if any.
  SyncEngine? syncEngine;

  /// [CacheNexusMode.dev] records events and stats for the dev tools;
  /// [CacheNexusMode.production] skips that work.
  final CacheNexusMode mode;
  CacheContext? _context;
  bool _disposed = false;

  late final ObservabilityManager _observability;
  late final PolicyResolver _policyResolver;
  late final ReactiveEngine _reactiveEngine;

  final Map<Type, dynamic> _adapters = {};
  late final CacheTypeRegistry _registry = CacheTypeRegistry(_adapters);

  /// Creates a manager.
  ///
  /// Without [memoryStorage] a [MemoryCacheStorage] is used. Without
  /// [persistentStorage] nothing survives an app restart.
  CacheNexusManager({
    CacheStorage? memoryStorage,
    this.persistentStorage,
    this.syncEngine,
    this.mode = CacheNexusMode.production,
    CacheContext? context,
  }) : memoryStorage = memoryStorage ?? MemoryCacheStorage(),
       _context = context {
    _observability = ObservabilityManager(mode: mode);
    _policyResolver = PolicyResolver(
      observability: _observability,
      memoryStorage: this.memoryStorage,
      persistentStorage: persistentStorage,
      registry: _registry,
      legacyKeyOf: _legacyKeyOf,
    );
    _reactiveEngine = ReactiveEngine();
  }

  /// Cache and network events. Only emitted in [CacheNexusMode.dev].
  Stream<CacheEvent> get events => _observability.events;

  /// Hit/miss and network statistics. Only collected in [CacheNexusMode.dev].
  CacheStats get stats => _observability.stats;

  /// The active user context, if any.
  CacheContext? get context => _context;

  /// The last 100 events (dev mode only).
  List<CacheEvent> get recentEvents => _observability.recentEvents;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// The reactive engine, exposed for tests.
  @visibleForTesting
  ReactiveEngine get reactiveEngine => _reactiveEngine;

  /// Scopes every following key to [context] (e.g. after login).
  void setContext(CacheContext context) {
    _context = context;
  }

  /// Removes the user scope (e.g. after logout). Does not delete data; use
  /// [invalidateByContext] for that.
  void clearContext() {
    _context = null;
  }

  String _resolveKey(String key) {
    final ctx = _context;
    if (ctx != null) {
      return '${ctx.cacheKeyPrefix}$key';
    }
    return key;
  }

  String? _legacyKeyOf(String resolvedKey) {
    final ctx = _context;
    if (ctx == null || !resolvedKey.startsWith(ctx.cacheKeyPrefix)) {
      return null;
    }
    return ctx.legacyCacheKeyPrefix +
        resolvedKey.substring(ctx.cacheKeyPrefix.length);
  }

  /// Converts cached [data] to `T` using the registered adapters and the
  /// built-in collection decoders. Returns `null` when that is not possible.
  T? tryCast<T>(dynamic data) {
    final result = _registry.decode<T>(data);
    return result.ok ? result.value : null;
  }

  /// Watches [key]: the stream first delivers the current cached value (or
  /// `null`), then every change made through this manager, including
  /// `null` when the key is deleted, cleared or invalidated.
  ///
  /// Each listener receives its own initial value; adding a listener never
  /// re-emits to existing ones. A value that cannot be converted to `T` is
  /// delivered as a stream error ([CacheDecodeException]).
  Stream<T?> watch<T>(String key, {Duration? debounce}) {
    final resolvedKey = _resolveKey(key);
    return _reactiveEngine.watch<T>(
      resolvedKey,
      readCurrent: (rk) => _readCurrent<T>(rk),
      debounce: debounce,
      decode: (value) {
        if (value == null) return null;
        final result = _registry.decode<T>(value);
        if (result.ok) return result.value;
        throw CacheDecodeException(
          key: resolvedKey,
          requestedType: '$T',
          storedType: '${value.runtimeType}',
          cause: result.error,
        );
      },
    );
  }

  Future<T?> _readCurrent<T>(String resolvedKey) async {
    final memEntry = await memoryStorage.read(resolvedKey);
    if (memEntry != null && !memEntry.isExpired) {
      final result = _registry.decode<T>(memEntry.data);
      if (result.ok) return result.value;
    }

    final persistent = persistentStorage;
    if (persistent != null) {
      final entry = await persistent.read(resolvedKey);
      if (entry != null && !entry.isExpired) {
        final result = _registry.decode<T>(entry.data);
        if (result.ok) return result.value;
        throw CacheDecodeException(
          key: resolvedKey,
          requestedType: '$T',
          storedType: '${entry.data.runtimeType}',
          cause: result.error,
        );
      }
    }

    return null;
  }

  /// Reads [key] according to [policy], calling [fetcher] when the policy
  /// needs the network. Fresh results are stored with [ttl] and pushed to
  /// watchers.
  ///
  /// Errors thrown by [fetcher] reach the caller unless the policy can answer
  /// from the cache. See [CachePolicy] for each policy's exact behaviour.
  Future<T> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
    CachePolicy policy = CachePolicy.cacheFirst,
  }) {
    return _policyResolver.resolve<T>(
      resolvedKey: _resolveKey(key),
      fetcher: fetcher,
      ttl: ttl,
      policy: policy,
      onStore: (resolvedKey, data, t) =>
          _setResolved<T>(resolvedKey, data, ttl: t),
      // _setResolved already notified watchers; notifying again here would
      // make every fetch emit twice.
      onNotify: (resolvedKey, data) async {},
    );
  }

  Future<void> _setResolved<T>(
    String resolvedKey,
    T data, {
    Duration? ttl,
  }) async {
    final createdAt = DateTime.now();
    await memoryStorage.write(
      resolvedKey,
      CacheEntry<T>(data: data, createdAt: createdAt, ttl: ttl),
    );
    final persistent = persistentStorage;
    if (persistent != null) {
      await persistent.write(
        resolvedKey,
        CacheEntry<dynamic>(
          data: _registry.encode<T>(data),
          createdAt: createdAt,
          ttl: ttl,
        ),
      );
    }
    _reactiveEngine.emit(resolvedKey, data);
    _observability.emit(CacheEventType.store, resolvedKey, data: data);
  }

  /// Stores [data] under [key] in every tier and notifies watchers.
  Future<void> set<T>({
    required String key,
    required T data,
    Duration? ttl,
  }) async {
    final resolvedKey = _resolveKey(key);
    await _setResolved<T>(resolvedKey, data, ttl: ttl);
  }

  /// Adds [task] to the [syncEngine] queue. Throws an [Exception] when no
  /// sync engine was provided.
  Future<void> enqueueSyncTask(SyncTask task) async {
    final engine = syncEngine;
    if (engine == null) {
      throw Exception('SyncEngine not initialized');
    }
    await engine.enqueue(task);
  }

  /// Removes [key] from every tier and notifies its watchers with `null`.
  Future<void> delete(String key) async {
    final resolvedKey = _resolveKey(key);
    await memoryStorage.delete(resolvedKey);
    if (persistentStorage != null) {
      await persistentStorage!.delete(resolvedKey);
    }
    _reactiveEngine.emit(resolvedKey, null);
    _observability.emit(CacheEventType.evict, resolvedKey);
  }

  /// Removes everything from every tier and notifies all watchers with
  /// `null`.
  Future<void> clear() async {
    await memoryStorage.clear();
    if (persistentStorage != null) {
      await persistentStorage!.clear();
    }
    _reactiveEngine.emitWhere((_) => true, null);
    _observability.emit(CacheEventType.evict, 'all');
  }

  /// Deletes the data cached for [context] and notifies the affected
  /// watchers with `null`.
  ///
  /// A context without a role removes all of that user's data (every role);
  /// a context with a role removes only that role's data.
  Future<void> invalidateByContext(CacheContext context) async {
    final prefixes = <String>{
      context.role == null ? context.userKeyPrefix : context.cacheKeyPrefix,
      context.legacyCacheKeyPrefix,
    };
    for (final prefix in prefixes) {
      await memoryStorage.deleteByPrefix(prefix);
      if (persistentStorage != null) {
        await persistentStorage!.deleteByPrefix(prefix);
      }
      _reactiveEngine.emitWhere((key) => key.startsWith(prefix), null);
      _observability.emit(CacheEventType.evict, 'prefix:$prefix');
    }
  }

  String recordNetworkRequest({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
  }) => _observability.recordNetworkRequest(
    url: url,
    method: method,
    headers: headers,
    body: body,
  );

  void recordNetworkResponse({
    required String requestId,
    required String url,
    required String method,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
  }) => _observability.recordNetworkResponse(
    requestId: requestId,
    url: url,
    method: method,
    statusCode: statusCode,
    headers: headers,
    body: body,
    duration: duration,
  );

  void recordNetworkError({
    required String requestId,
    required String url,
    required String method,
    required Object error,
    Map<String, dynamic>? headers,
    Duration? duration,
  }) => _observability.recordNetworkError(
    requestId: requestId,
    url: url,
    method: method,
    error: error,
    headers: headers,
    duration: duration,
  );

  Future<T> trackNetworkRequest<T>({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
    required Future<T> Function() request,
  }) => _observability.trackNetworkRequest(
    url: url,
    method: method,
    headers: headers,
    body: body,
    request: request,
  );

  /// Registers [adapter] so values of type `T` (and `T?`, `List<T>`,
  /// `Map<String, T>`) are written through [CacheAdapter.toData] and rebuilt
  /// through [CacheAdapter.fromData] after a restart.
  void registerAdapter<T>(CacheAdapter<T> adapter) {
    _registry.register<T>(adapter);
  }

  /// Releases streams and stops the [syncEngine].
  ///
  /// Requests that are already running complete normally; their results are
  /// still returned to the caller.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reactiveEngine.dispose();
    _observability.dispose();
    syncEngine?.dispose();
  }
}
