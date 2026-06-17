import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache_entry.dart';
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
import 'type_adapter.dart';

class CacheNexusManager {
  final CacheStorage memoryStorage;
  final CacheStorage? persistentStorage;
  SyncEngine? syncEngine;
  final CacheNexusMode mode;
  CacheContext? _context;

  late final ObservabilityManager _observability;
  late final PolicyResolver _policyResolver;
  late final ReactiveEngine _reactiveEngine;

  final Map<Type, dynamic> _adapters = {};

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
      adapters: _adapters,
    );
    _reactiveEngine = ReactiveEngine();
  }

  Stream<CacheEvent> get events => _observability.events;
  CacheStats get stats => _observability.stats;
  CacheContext? get context => _context;
  List<CacheEvent> get recentEvents => _observability.recentEvents;

  @visibleForTesting
  ReactiveEngine get reactiveEngine => _reactiveEngine;

  void setContext(CacheContext context) {
    _context = context;
  }

  void clearContext() {
    _context = null;
  }

  String _resolveKey(String key) {
    if (_context != null) {
      return '${_context!.cacheKeyPrefix}$key';
    }
    return key;
  }

  T? tryCast<T>(dynamic data) {
    final adapter = _adapters[T];
    if (adapter != null) {
      return (adapter as TypeAdapter<T>).fromData(data);
    }
    if (data is T) return data;
    try {
      return data as T;
    } catch (_) {
      return null;
    }
  }

  Stream<T?> watch<T>(String key, {Duration? debounce}) {
    final resolvedKey = _resolveKey(key);
    return _reactiveEngine.watch<T>(
      resolvedKey,
      readCurrent: (rk) => _readCurrent<T>(rk),
      debounce: debounce,
    );
  }

  Future<T?> _readCurrent<T>(String resolvedKey) async {
    var entry = await memoryStorage.read(resolvedKey);
    if (entry != null && !entry.isExpired) {
      return entry.data as T;
    }

    if (persistentStorage != null) {
      entry = await persistentStorage!.read(resolvedKey);
      if (entry != null && !entry.isExpired) {
        return tryCast<T>(entry.data);
      }
    }

    return null;
  }

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
      onNotify: (resolvedKey, data) async {
        _reactiveEngine.emit(resolvedKey, data);
      },
    );
  }

  Future<void> _setResolved<T>(
    String resolvedKey,
    T data, {
    Duration? ttl,
  }) async {
    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    await memoryStorage.write(resolvedKey, entry);
    if (persistentStorage != null) {
      await persistentStorage!.write(resolvedKey, entry);
    }
    _reactiveEngine.emit(resolvedKey, data);
    _observability.emit(CacheEventType.store, resolvedKey, data: data);
  }

  Future<void> set<T>({
    required String key,
    required T data,
    Duration? ttl,
  }) async {
    final resolvedKey = _resolveKey(key);
    await _setResolved<T>(resolvedKey, data, ttl: ttl);
  }

  Future<void> enqueueSyncTask(SyncTask task) async {
    if (syncEngine != null) {
      await syncEngine!.enqueue(task);
    } else {
      throw Exception('SyncEngine not initialized');
    }
  }

  Future<void> delete(String key) async {
    final resolvedKey = _resolveKey(key);
    await memoryStorage.delete(resolvedKey);
    if (persistentStorage != null) {
      await persistentStorage!.delete(resolvedKey);
    }
    _reactiveEngine.emit(resolvedKey, null);
    _observability.emit(CacheEventType.evict, resolvedKey);
  }

  Future<void> clear() async {
    await memoryStorage.clear();
    if (persistentStorage != null) {
      await persistentStorage!.clear();
    }
    _observability.emit(CacheEventType.evict, 'all');
  }

  Future<void> invalidateByContext(CacheContext context) async {
    final prefix = context.cacheKeyPrefix;
    await memoryStorage.deleteByPrefix(prefix);
    if (persistentStorage != null) {
      await persistentStorage!.deleteByPrefix(prefix);
    }
    _observability.emit(CacheEventType.evict, 'prefix:$prefix');
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

  void registerAdapter<T>(TypeAdapter<T> adapter) {
    _adapters[T] = adapter;
  }

  void dispose() {
    _reactiveEngine.dispose();
    _observability.dispose();
  }
}
