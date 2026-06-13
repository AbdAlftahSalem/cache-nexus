import 'dart:async';
import 'cache_entry.dart';
import 'cache_storage.dart';
import 'memory_cache_storage.dart';
import 'cache_policy.dart';
import 'cache_event.dart';
import 'cache_stats.dart';
import 'sync_task.dart';
import 'sync_engine.dart';
import 'network_status.dart';
import 'cache_context.dart';

enum SmartCacheMode { dev, production }

class SmartCacheManager {
  final CacheStorage memoryStorage;
  final CacheStorage? persistentStorage;
  final SyncEngine? syncEngine;
  final SmartCacheMode mode;
  CacheContext? _context;
  final Map<String, Future<dynamic>> _inFlightRequests = {};
  
  final StreamController<CacheEvent> _eventController = StreamController<CacheEvent>.broadcast();
  CacheStats _stats = CacheStats();

  SmartCacheManager({
    CacheStorage? memoryStorage,
    this.persistentStorage,
    this.syncEngine,
    this.mode = SmartCacheMode.production,
    CacheContext? context,
  }) : memoryStorage = memoryStorage ?? MemoryCacheStorage(),
       _context = context;

  Stream<CacheEvent> get events => _eventController.stream;
  CacheStats get stats => _stats;
  CacheContext? get context => _context;

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

  void _emit(CacheEventType type, String key, {dynamic data, Duration? duration, Object? error}) {
    if (mode != SmartCacheMode.dev) return;

    final event = CacheEvent(
      key: key,
      type: type,
      timestamp: DateTime.now(),
      data: data,
      duration: duration,
      error: error,
    );

    switch (type) {
      case CacheEventType.hit:
        _stats = _stats.copyWith(hits: _stats.hits + 1);
        break;
      case CacheEventType.miss:
        _stats = _stats.copyWith(misses: _stats.misses + 1);
        break;
      case CacheEventType.fetch:
        _stats = _stats.copyWith(fetches: _stats.fetches + 1);
        break;
      case CacheEventType.error:
        _stats = _stats.copyWith(errors: _stats.errors + 1);
        break;
      default:
        break;
    }

    _eventController.add(event);
  }

  Future<T> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
    CachePolicy policy = CachePolicy.cacheFirst,
  }) async {
    final resolvedKey = _resolveKey(key);
    switch (policy) {
      case CachePolicy.cacheFirst:
        // 1. Check Memory
        var entry = await memoryStorage.read(resolvedKey);
        if (entry != null) {
          if (!entry.isExpired) {
            _emit(CacheEventType.hit, resolvedKey, data: entry.data);
            return entry.data as T;
          } else {
            _emit(CacheEventType.expired, resolvedKey);
          }
        }

        // 2. Check Persistent
        if (persistentStorage != null) {
          entry = await persistentStorage!.read(resolvedKey);
          if (entry != null) {
            if (!entry.isExpired) {
              _emit(CacheEventType.hit, resolvedKey, data: entry.data);
              // Restore to memory
              await memoryStorage.write(resolvedKey, entry);
              return entry.data as T;
            } else {
              _emit(CacheEventType.expired, resolvedKey);
            }
          }
        }

        _emit(CacheEventType.miss, resolvedKey);
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.networkFirst:
        if (await NetworkStatus.isOnline) {
          try {
            return await _performFetch(key, fetcher, ttl);
          } catch (e) {
            return await _readFromCache(resolvedKey);
          }
        } else {
          return await _readFromCache(resolvedKey);
        }

      case CachePolicy.cacheOnly:
        return await _readFromCache(resolvedKey);

      case CachePolicy.networkOnly:
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.staleWhileRevalidate:
        final entry = await memoryStorage.read(resolvedKey) ?? (persistentStorage != null ? await persistentStorage!.read(resolvedKey) : null);
        if (entry != null) {
          _emit(CacheEventType.hit, resolvedKey, data: entry.data);
          // Trigger background refresh silently if online
          NetworkStatus.isOnline.then((online) {
            if (online) {
              _performFetch(key, fetcher, ttl).catchError((_) => null);
            }
          });
          return entry.data as T;
        }
        _emit(CacheEventType.miss, resolvedKey);
        return _performFetch(key, fetcher, ttl);
    }
  }

  Future<T> _readFromCache<T>(String resolvedKey) async {
    var entry = await memoryStorage.read(resolvedKey);
    if (entry != null) {
      if (!entry.isExpired) {
        _emit(CacheEventType.hit, resolvedKey, data: entry.data);
        return entry.data as T;
      } else {
        _emit(CacheEventType.expired, resolvedKey);
        await memoryStorage.delete(resolvedKey);
      }
    }
    if (persistentStorage != null) {
      entry = await persistentStorage!.read(resolvedKey);
      if (entry != null) {
        if (!entry.isExpired) {
          _emit(CacheEventType.hit, resolvedKey, data: entry.data);
          await memoryStorage.write(resolvedKey, entry);
          return entry.data as T;
        } else {
          _emit(CacheEventType.expired, resolvedKey);
          await persistentStorage!.delete(resolvedKey);
        }
      }
    }
    _emit(CacheEventType.miss, resolvedKey);
    throw Exception('Cache missing or expired for key: $resolvedKey');
  }

  Future<T> _performFetch<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
  ) async {
    final resolvedKey = _resolveKey(key);
    if (_inFlightRequests.containsKey(resolvedKey)) {
      return (await _inFlightRequests[resolvedKey]) as T;
    }

    final stopwatch = Stopwatch()..start();
    final future = fetcher();
    _inFlightRequests[resolvedKey] = future;

    try {
      final result = await future;

      if (result == null) {
        throw Exception('Fetcher returned null result for key: $resolvedKey');
      }

      _emit(CacheEventType.fetch, resolvedKey, data: result, duration: stopwatch.elapsed);
      await set(key: key, data: result, ttl: ttl);
      return result;
    } catch (e) {
      _emit(CacheEventType.error, resolvedKey, error: e, duration: stopwatch.elapsed);
      rethrow;
    } finally {
      stopwatch.stop();
      _inFlightRequests.remove(resolvedKey);
    }
  }

  Future<void> set<T>({
    required String key,
    required T data,
    Duration? ttl,
  }) async {
    final resolvedKey = _resolveKey(key);
    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    await memoryStorage.write(resolvedKey, entry);
    if (persistentStorage != null) {
      await persistentStorage!.write(resolvedKey, entry);
    }
    _emit(CacheEventType.store, resolvedKey, data: data);
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
    _emit(CacheEventType.evict, resolvedKey);
  }

  Future<void> clear() async {
    await memoryStorage.clear();
    if (persistentStorage != null) {
      await persistentStorage!.clear();
    }
    _emit(CacheEventType.evict, 'all');
  }

  Future<void> invalidateByContext(CacheContext context) async {
    final prefix = context.cacheKeyPrefix;
    await memoryStorage.deleteByPrefix(prefix);
    if (persistentStorage != null) {
      await persistentStorage!.deleteByPrefix(prefix);
    }
    _emit(CacheEventType.evict, 'prefix:$prefix');
  }

  void dispose() {
    _eventController.close();
  }
}
