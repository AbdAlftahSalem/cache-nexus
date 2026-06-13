import 'package:test/test.dart';
import 'package:smart_cache/smart_cache.dart';

void main() {
  late SmartCacheManager devCache;
  late SmartCacheManager prodCache;
  late MemoryCacheStorage storage;

  setUp(() {
    storage = MemoryCacheStorage();
    devCache = SmartCacheManager(memoryStorage: storage, mode: SmartCacheMode.dev);
    prodCache = SmartCacheManager(memoryStorage: storage, mode: SmartCacheMode.production);
  });

  group('SmartCacheManager Phase 3 - Observability', () {
    test('dev mode emits events and updates stats', () async {
      final futureEvent = devCache.events.firstWhere((e) => e.type == CacheEventType.fetch);

      await devCache.get<String>(
        key: 'test',
        fetcher: () async => 'data',
      );

      final event = await futureEvent.timeout(Duration(seconds: 1));

      expect(event.key, 'test');
      expect(devCache.stats.fetches, 1);
      expect(devCache.stats.misses, 1);
    });

    test('production mode does NOT emit events or update stats', () async {
      final events = <CacheEvent>[];
      prodCache.events.listen(events.add);

      await prodCache.get<String>(
        key: 'test',
        fetcher: () async => 'data',
      );

      // Give it a tiny bit of time for any async events
      await Future.delayed(Duration(milliseconds: 10));

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
      final futureEvent = devCache.events.firstWhere((e) => e.type == CacheEventType.error);

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
  });
}
