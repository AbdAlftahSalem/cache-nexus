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

enum SmartCacheMode { dev, production }

class SmartCacheManager {
  final CacheStorage memoryStorage;
  final CacheStorage? persistentStorage;
  final SyncEngine? syncEngine;
  final SmartCacheMode mode;
  final Map<String, Future<dynamic>> _inFlightRequests = {};
  
  final StreamController<CacheEvent> _eventController = StreamController<CacheEvent>.broadcast();
  CacheStats _stats = CacheStats();

  SmartCacheManager({
    CacheStorage? memoryStorage,
    this.persistentStorage,
    this.syncEngine,
    this.mode = SmartCacheMode.production,
  }) : memoryStorage = memoryStorage ?? MemoryCacheStorage();

  Stream<CacheEvent> get events => _eventController.stream;
  CacheStats get stats => _stats;

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
    switch (policy) {
      case CachePolicy.cacheFirst:
        // 1. Check Memory
        var entry = await memoryStorage.read(key);
        if (entry != null) {
          if (!entry.isExpired) {
            _emit(CacheEventType.hit, key, data: entry.data);
            return entry.data as T;
          } else {
            _emit(CacheEventType.expired, key);
          }
        }

        // 2. Check Persistent
        if (persistentStorage != null) {
          entry = await persistentStorage!.read(key);
          if (entry != null) {
            if (!entry.isExpired) {
              _emit(CacheEventType.hit, key, data: entry.data);
              // Restore to memory
              await memoryStorage.write(key, entry);
              return entry.data as T;
            } else {
              _emit(CacheEventType.expired, key);
            }
          }
        }

        _emit(CacheEventType.miss, key);
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.networkFirst:
        if (await NetworkStatus.isOnline) {
          try {
            return await _performFetch(key, fetcher, ttl);
          } catch (e) {
            return await _readFromCache(key);
          }
        } else {
          return await _readFromCache(key);
        }

      case CachePolicy.cacheOnly:
        return await _readFromCache(key);

      case CachePolicy.networkOnly:
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.staleWhileRevalidate:
        final entry = await memoryStorage.read(key) ?? (persistentStorage != null ? await persistentStorage!.read(key) : null);
        if (entry != null) {
          _emit(CacheEventType.hit, key, data: entry.data);
          // Trigger background refresh silently if online
          NetworkStatus.isOnline.then((online) {
            if (online) {
              _performFetch(key, fetcher, ttl).catchError((_) => null);
            }
          });
          return entry.data as T;
        }
        _emit(CacheEventType.miss, key);
        return _performFetch(key, fetcher, ttl);
    }
  }

  Future<T> _readFromCache<T>(String key) async {
    var entry = await memoryStorage.read(key);
    if (entry != null) {
      if (!entry.isExpired) {
        _emit(CacheEventType.hit, key, data: entry.data);
        return entry.data as T;
      } else {
        _emit(CacheEventType.expired, key);
        await memoryStorage.delete(key);
      }
    }
    if (persistentStorage != null) {
      entry = await persistentStorage!.read(key);
      if (entry != null) {
        if (!entry.isExpired) {
          _emit(CacheEventType.hit, key, data: entry.data);
          await memoryStorage.write(key, entry);
          return entry.data as T;
        } else {
          _emit(CacheEventType.expired, key);
          await persistentStorage!.delete(key);
        }
      }
    }
    _emit(CacheEventType.miss, key);
    throw Exception('Cache missing or expired for key: $key');
  }

  Future<T> _performFetch<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
  ) async {
    if (_inFlightRequests.containsKey(key)) {
      return (await _inFlightRequests[key]) as T;
    }

    final stopwatch = Stopwatch()..start();
    final future = fetcher();
    _inFlightRequests[key] = future;

    try {
      final result = await future;

      if (result == null) {
        throw Exception('Fetcher returned null result for key: $key');
      }

      _emit(CacheEventType.fetch, key, data: result, duration: stopwatch.elapsed);
      await set(key: key, data: result, ttl: ttl);
      return result;
    } catch (e) {
      _emit(CacheEventType.error, key, error: e, duration: stopwatch.elapsed);
      rethrow;
    } finally {
      stopwatch.stop();
      _inFlightRequests.remove(key);
    }
  }

  Future<void> set<T>({
    required String key,
    required T data,
    Duration? ttl,
  }) async {
    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    await memoryStorage.write(key, entry);
    if (persistentStorage != null) {
      await persistentStorage!.write(key, entry);
    }
    _emit(CacheEventType.store, key, data: data);
  }

  Future<void> enqueueSyncTask(SyncTask task) async {
    if (syncEngine != null) {
      await syncEngine!.enqueue(task);
    } else {
      throw Exception('SyncEngine not initialized');
    }
  }

  Future<void> delete(String key) async {
    await memoryStorage.delete(key);
    if (persistentStorage != null) {
      await persistentStorage!.delete(key);
    }
    _emit(CacheEventType.evict, key);
  }

  Future<void> clear() async {
    await memoryStorage.clear();
    if (persistentStorage != null) {
      await persistentStorage!.clear();
    }
    _emit(CacheEventType.evict, 'all');
  }

  void dispose() {
    _eventController.close();
  }
}
