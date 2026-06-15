import 'dart:async';

import 'cache_storage.dart';
import 'cache_policy.dart';
import 'cache_event.dart';
import 'network_status.dart';
import 'observability_manager.dart';

class PolicyResolver {
  final ObservabilityManager _observability;
  final CacheStorage _memoryStorage;
  final CacheStorage? _persistentStorage;
  final Map<String, Future<dynamic>> _inFlightRequests = {};

  PolicyResolver({
    required ObservabilityManager observability,
    required CacheStorage memoryStorage,
    CacheStorage? persistentStorage,
  })  : _observability = observability,
        _memoryStorage = memoryStorage,
        _persistentStorage = persistentStorage;

  static T? _tryCast<T>(dynamic data) {
    try {
      return data as T;
    } catch (_) {
      return null;
    }
  }

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
        return _readFromCache<T>(resolvedKey, onNotify);
      case CachePolicy.networkOnly:
        return _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
      case CachePolicy.staleWhileRevalidate:
        return _staleWhileRevalidate<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
    }
  }

  Future<T> _cacheFirst<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    var entry = await _memoryStorage.read(resolvedKey);
    if (entry != null) {
      if (!entry.isExpired) {
        _observability.emit(CacheEventType.hit, resolvedKey, data: entry.data);
        return entry.data as T;
      } else {
        _observability.emit(CacheEventType.expired, resolvedKey);
      }
    }

    if (_persistentStorage != null) {
      entry = await _persistentStorage.read(resolvedKey);
      if (entry != null) {
        if (!entry.isExpired) {
          final casted = _tryCast<T>(entry.data);
          if (casted != null) {
            _observability.emit(CacheEventType.hit, resolvedKey, data: entry.data);
            await _memoryStorage.write(resolvedKey, entry);
            return casted;
          }
        } else {
          _observability.emit(CacheEventType.expired, resolvedKey);
        }
      }
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
    if (await NetworkStatus.isOnline) {
      try {
        return await _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
      } catch (e) {
        return await _readFromCache<T>(resolvedKey, onNotify);
      }
    } else {
      return await _readFromCache<T>(resolvedKey, onNotify);
    }
  }

  Future<T> _readFromCache<T>(
    String resolvedKey,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    var entry = await _memoryStorage.read(resolvedKey);
    if (entry != null) {
      if (!entry.isExpired) {
        _observability.emit(CacheEventType.hit, resolvedKey, data: entry.data);
        return entry.data as T;
      } else {
        _observability.emit(CacheEventType.expired, resolvedKey);
        await _memoryStorage.delete(resolvedKey);
      }
    }
    if (_persistentStorage != null) {
      entry = await _persistentStorage.read(resolvedKey);
      if (entry != null) {
        if (!entry.isExpired) {
          final casted = _tryCast<T>(entry.data);
          if (casted != null) {
            _observability.emit(CacheEventType.hit, resolvedKey, data: entry.data);
            await _memoryStorage.write(resolvedKey, entry);
            return casted;
          }
        } else {
          _observability.emit(CacheEventType.expired, resolvedKey);
          await _persistentStorage.delete(resolvedKey);
        }
      }
    }
    _observability.emit(CacheEventType.miss, resolvedKey);
    throw Exception('Cache missing or expired for key: $resolvedKey');
  }

  Future<T> _performFetch<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
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

      _observability.emit(CacheEventType.fetch, resolvedKey, data: result, duration: stopwatch.elapsed);
      await onStore(resolvedKey, result, ttl);
      await onNotify(resolvedKey, result);
      return result;
    } catch (e) {
      _observability.emit(CacheEventType.error, resolvedKey, error: e, duration: stopwatch.elapsed);
      rethrow;
    } finally {
      stopwatch.stop();
      _inFlightRequests.remove(resolvedKey);
    }
  }

  Future<T> _staleWhileRevalidate<T>(
    String resolvedKey,
    Future<T> Function() fetcher,
    Duration? ttl,
    Future<void> Function(String key, T data, Duration? ttl) onStore,
    Future<void> Function(String key, dynamic data) onNotify,
  ) async {
    var entry = await _memoryStorage.read(resolvedKey);
    T? casted;
    if (entry != null && !entry.isExpired) {
      casted = _tryCast<T>(entry.data);
    }
    if (casted == null && _persistentStorage != null) {
      entry = await _persistentStorage.read(resolvedKey);
      if (entry != null && !entry.isExpired) {
        casted = _tryCast<T>(entry.data);
      }
    }
    if (casted != null) {
      _observability.emit(CacheEventType.hit, resolvedKey, data: casted);
      NetworkStatus.isOnline.then((online) async {
        if (online) {
          try {
            await _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
          } catch (_) {}
        }
      });
      return casted;
    }
    _observability.emit(CacheEventType.miss, resolvedKey);
    return _performFetch<T>(resolvedKey, fetcher, ttl, onStore, onNotify);
  }
}
