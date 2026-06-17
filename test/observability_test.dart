import 'dart:async';

import 'package:test/test.dart';
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  late CacheNexusManager devCache;
  late CacheNexusManager prodCache;
  late MemoryCacheStorage storage;

  setUp(() {
    storage = MemoryCacheStorage();
    devCache = CacheNexusManager(
      memoryStorage: storage,
      mode: CacheNexusMode.dev,
    );
    prodCache = CacheNexusManager(
      memoryStorage: storage,
      mode: CacheNexusMode.production,
    );
  });

  group('CacheNexusManager Phase 3 - Observability', () {
    test('dev mode emits events and updates stats', () async {
      final futureEvent = devCache.events.firstWhere(
        (e) => e.type == CacheEventType.fetch,
      );

      await devCache.get<String>(key: 'test', fetcher: () async => 'data');

      final event = await futureEvent.timeout(Duration(seconds: 1));

      expect(event.key, 'test');
      expect(devCache.stats.fetches, 1);
      expect(devCache.stats.misses, 1);
    });

    test('production mode does NOT emit events or update stats', () async {
      final events = <CacheEvent>[];
      prodCache.events.listen(events.add);

      await prodCache.get<String>(key: 'test', fetcher: () async => 'data');

      // Give it a tiny bit of time for any async events
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(events, isEmpty);
      expect(prodCache.stats.fetches, 0);
      expect(prodCache.stats.misses, 0);
    });

    test('cache hit updates stats correctly', () async {
      await devCache.set(key: 'hit_test', data: 'cached');

      await devCache.get<String>(
        key: 'hit_test',
        fetcher: () async => 'new_data',
      );

      expect(devCache.stats.hits, 1);
      expect(devCache.stats.hitRate, 1.0);
    });

    test('error emits error event with duration', () async {
      final futureEvent = devCache.events.firstWhere(
        (e) => e.type == CacheEventType.error,
      );

      try {
        await devCache.get<String>(
          key: 'error_test',
          fetcher: () async => throw Exception('Fetch failed'),
        );
      } catch (_) {}

      final errorEvent = await futureEvent.timeout(Duration(seconds: 1));
      expect(errorEvent.error.toString(), contains('Fetch failed'));
      expect(errorEvent.duration, isNotNull);
    });

    test('set() emits store event', () async {
      final futureEvent = devCache.events.firstWhere(
        (e) => e.type == CacheEventType.store,
      );

      await devCache.set(key: 'stored', data: 'value');

      final event = await futureEvent.timeout(Duration(seconds: 1));
      expect(event.key, 'stored');
      expect(event.data, 'value');
    });

    test('delete() emits evict event', () async {
      await devCache.set(key: 'to_delete', data: 'value');

      final futureEvent = devCache.events.firstWhere(
        (e) => e.type == CacheEventType.evict,
      );

      await devCache.delete('to_delete');

      final event = await futureEvent.timeout(Duration(seconds: 1));
      expect(event.key, 'to_delete');
    });

    test('expired key emits expired event', () async {
      await devCache.set(
        key: 'ttl_key',
        data: 'old',
        ttl: Duration(milliseconds: 1),
      );
      await Future<void>.delayed(Duration(milliseconds: 10));

      final futureEvent = devCache.events.firstWhere(
        (e) => e.type == CacheEventType.expired,
      );

      await devCache.get<String>(key: 'ttl_key', fetcher: () async => 'fresh');

      final event = await futureEvent.timeout(Duration(seconds: 1));
      expect(event.key, 'ttl_key');
    });

    test('recentEvents returns recent events in reverse order', () async {
      await devCache.set(key: 'a', data: 1);
      await devCache.set(key: 'b', data: 2);

      final recent = devCache.recentEvents;
      expect(recent.length, greaterThanOrEqualTo(2));
      expect(recent.first.key, 'b');
      expect(recent[1].key, 'a');
    });

    test('recentEvents caps at 100', () async {
      for (var i = 0; i < 120; i++) {
        await devCache.set(key: 'k_$i', data: i);
      }

      expect(devCache.recentEvents.length, 100);
      expect(devCache.recentEvents.first.key, 'k_119');
    });

    test('dispose closes event stream', () async {
      final manager = CacheNexusManager(
        memoryStorage: MemoryCacheStorage(),
        mode: CacheNexusMode.dev,
      );
      final done = Completer<void>();
      manager.events.listen((_) {}, onDone: () => done.complete());

      manager.dispose();
      await Future<void>.delayed(Duration(milliseconds: 50));

      expect(done.isCompleted, isTrue);
    });
  });

  group('ObservabilityManager - Network Recording', () {
    late CacheNexusManager cache;

    setUp(() {
      NetworkStatus.setMockStatus(true);
      cache = CacheNexusManager(
        memoryStorage: MemoryCacheStorage(),
        mode: CacheNexusMode.dev,
      );
    });

    tearDown(() {
      cache.dispose();
    });

    test('recordNetworkRequest returns a request ID', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      final id = cache.recordNetworkRequest(
        url: 'https://api.example.com/posts',
        method: 'GET',
      );

      expect(id, isNotEmpty);
      expect(id, startsWith('req_'));

      await Future<void>.delayed(Duration(milliseconds: 10));
      expect(
        events.any((e) => e.type == CacheEventType.networkRequest),
        isTrue,
      );
    });

    test('recordNetworkResponse updates stats and emits event', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      final id = cache.recordNetworkRequest(
        url: 'https://api.example.com/posts',
        method: 'GET',
      );
      cache.recordNetworkResponse(
        requestId: id,
        url: 'https://api.example.com/posts',
        method: 'GET',
        statusCode: 200,
        duration: Duration(milliseconds: 150),
      );

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(cache.stats.totalRequests, 1);
      expect(cache.stats.successfulRequests, 1);
      expect(cache.stats.totalResponseTimeMs, 150);
      expect(
        events.any((e) => e.type == CacheEventType.networkResponse),
        isTrue,
      );
    });

    test('recordNetworkError updates stats and emits event', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      final id = cache.recordNetworkRequest(
        url: 'https://api.example.com/posts',
        method: 'POST',
      );
      cache.recordNetworkError(
        requestId: id,
        url: 'https://api.example.com/posts',
        method: 'POST',
        error: Exception('Timeout'),
        duration: Duration(milliseconds: 300),
      );

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(cache.stats.totalRequests, 1);
      expect(cache.stats.failedRequests, 1);
      expect(events.any((e) => e.type == CacheEventType.networkError), isTrue);
    });

    test('trackNetworkRequest records success', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      final result = await cache.trackNetworkRequest<String>(
        url: 'https://api.example.com/data',
        method: 'GET',
        request: () async => 'ok',
      );

      expect(result, 'ok');
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(cache.stats.totalRequests, 1);
      expect(cache.stats.successfulRequests, 1);
      expect(
        events.any((e) => e.type == CacheEventType.networkRequest),
        isTrue,
      );
      expect(
        events.any((e) => e.type == CacheEventType.networkResponse),
        isTrue,
      );
    });

    test('trackNetworkRequest records error', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      try {
        await cache.trackNetworkRequest<String>(
          url: 'https://api.example.com/fail',
          method: 'POST',
          request: () async => throw Exception('Network error'),
        );
      } catch (_) {}

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(cache.stats.totalRequests, 1);
      expect(cache.stats.failedRequests, 1);
      expect(events.any((e) => e.type == CacheEventType.networkError), isTrue);
    });

    test('network events have requestId correlation', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      final id = cache.recordNetworkRequest(
        url: 'https://api.example.com/corr',
        method: 'PUT',
      );
      cache.recordNetworkResponse(
        requestId: id,
        url: 'https://api.example.com/corr',
        method: 'PUT',
        statusCode: 201,
      );

      await Future<void>.delayed(Duration(milliseconds: 10));

      final reqEvents = events
          .where((e) => e.type == CacheEventType.networkRequest)
          .toList();
      final resEvents = events
          .where((e) => e.type == CacheEventType.networkResponse)
          .toList();
      expect(reqEvents.first.requestId, isNotEmpty);
      expect(resEvents.first.requestId, reqEvents.first.requestId);
    });
  });
}
