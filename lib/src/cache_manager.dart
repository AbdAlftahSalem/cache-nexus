import 'dart:async';
import 'cache_entry.dart';
import 'cache_storage.dart';
import 'cache_policy.dart';
import 'cache_event.dart';
import 'cache_stats.dart';

enum SmartCacheMode { dev, production }

class SmartCacheManager {
  final CacheStorage storage;
  final SmartCacheMode mode;
  final Map<String, Future<dynamic>> _inFlightRequests = {};
  
  final StreamController<CacheEvent> _eventController = StreamController<CacheEvent>.broadcast();
  CacheStats _stats = CacheStats();

  SmartCacheManager({
    required this.storage,
    this.mode = SmartCacheMode.production,
  });

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
        final entry = await storage.read(key);
        if (entry != null) {
          if (!entry.isExpired) {
            _emit(CacheEventType.hit, key, data: entry.data);
            return entry.data as T;
          } else {
            _emit(CacheEventType.expired, key);
          }
        } else {
          _emit(CacheEventType.miss, key);
        }
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.networkFirst:
        try {
          return await _performFetch(key, fetcher, ttl);
        } catch (e) {
          final entry = await storage.read(key);
          if (entry != null) {
            _emit(CacheEventType.hit, key, data: entry.data);
            return entry.data as T;
          }
          rethrow;
        }

      case CachePolicy.cacheOnly:
        final entry = await storage.read(key);
        if (entry != null) {
          _emit(CacheEventType.hit, key, data: entry.data);
          return entry.data as T;
        }
        _emit(CacheEventType.miss, key);
        throw Exception('Cache missing for key: $key');

      case CachePolicy.networkOnly:
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.staleWhileRevalidate:
        final entry = await storage.read(key);
        if (entry != null) {
          _emit(CacheEventType.hit, key, data: entry.data);
          // Trigger background refresh silently
          _performFetch(key, fetcher, ttl).catchError((_) {
            // Silently ignore background errors as per requirement
            return null;
          });
          return entry.data as T;
        }
        _emit(CacheEventType.miss, key);
        return _performFetch(key, fetcher, ttl);
    }
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

      // ignore: unnecessary_null_comparison
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
    await storage.write(key, entry);
    _emit(CacheEventType.store, key, data: data);
  }

  Future<void> delete(String key) async {
    await storage.delete(key);
    _emit(CacheEventType.evict, key);
  }

  Future<void> clear() async {
    await storage.clear();
    _emit(CacheEventType.evict, 'all');
  }

  void dispose() {
    _eventController.close();
  }
}
