import 'cache_entry.dart';
import 'cache_storage.dart';
import 'cache_policy.dart';

class SmartCacheManager {
  final CacheStorage storage;
  final Map<String, Future<dynamic>> _inFlightRequests = {};

  SmartCacheManager({required this.storage});

  Future<T> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
    CachePolicy policy = CachePolicy.cacheFirst,
  }) async {
    switch (policy) {
      case CachePolicy.cacheFirst:
        final entry = await storage.read(key);
        if (entry != null && !entry.isExpired) {
          return entry.data as T;
        }
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.networkFirst:
        try {
          return await _performFetch(key, fetcher, ttl);
        } catch (e) {
          final entry = await storage.read(key);
          if (entry != null) {
            return entry.data as T;
          }
          rethrow;
        }

      case CachePolicy.cacheOnly:
        final entry = await storage.read(key);
        if (entry != null) {
          return entry.data as T;
        }
        throw Exception('Cache missing for key: $key');

      case CachePolicy.networkOnly:
        return _performFetch(key, fetcher, ttl);

      case CachePolicy.staleWhileRevalidate:
        final entry = await storage.read(key);
        if (entry != null) {
          // Trigger background refresh silently
          _performFetch(key, fetcher, ttl).catchError((_) {
            // Silently ignore background errors as per requirement
            return null;
          });
          return entry.data as T;
        }
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

    final future = fetcher();
    _inFlightRequests[key] = future;

    try {
      final result = await future;

      // ignore: unnecessary_null_comparison
      if (result == null) {
        throw Exception('Fetcher returned null result for key: $key');
      }

      await set(key: key, data: result, ttl: ttl);
      return result;
    } finally {
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
  }

  Future<void> delete(String key) async {
    await storage.delete(key);
  }

  Future<void> clear() async {
    await storage.clear();
  }
}
