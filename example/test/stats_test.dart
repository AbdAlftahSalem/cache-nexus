import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';

void main() {
  late SmartCacheManager devCache;
  late SmartCacheManager prodCache;
  late MemoryCacheStorage storage;

  setUp(() {
    NetworkStatus.setMockStatus(true);
    storage = MemoryCacheStorage();
    devCache = SmartCacheManager(memoryStorage: storage, mode: SmartCacheMode.dev);
    prodCache = SmartCacheManager(memoryStorage: storage, mode: SmartCacheMode.production);
  });

  tearDown(() {
    devCache.dispose();
    prodCache.dispose();
  });

  test('dev mode tracks hit/miss/fetch/errors', () async {
    await devCache.get<String>(
      key: 'test',
      fetcher: () async => 'data',
    );

    expect(devCache.stats.misses, 1);
    expect(devCache.stats.fetches, 1);

    await devCache.set(key: 'cached', data: 'value');
    await devCache.get<String>(
      key: 'cached',
      fetcher: () async => 'new_data',
    );

    expect(devCache.stats.hits, 1);
  });

  test('hitRate calculated correctly', () async {
    await devCache.set(key: 'a', data: '1');
    await devCache.set(key: 'b', data: '2');

    await devCache.get<String>(key: 'a', fetcher: () async => 'x');
    await devCache.get<String>(key: 'b', fetcher: () async => 'x');

    expect(devCache.stats.hits, 2);
    expect(devCache.stats.misses, 0);
    expect(devCache.stats.hitRate, 1.0);

    await devCache.get<String>(key: 'new', fetcher: () async => 'y');
    expect(devCache.stats.misses, 1);
    expect(devCache.stats.hitRate, closeTo(0.667, 0.01));
  });

  test('events stream emits all event types', () async {
    final eventTypes = <CacheEventType>[];
    final sub = devCache.events.listen((e) => eventTypes.add(e.type));

    await devCache.set(key: 'event_test', data: 'data');
    await devCache.get<String>(
      key: 'event_test',
      fetcher: () async => 'data',
    );
    await devCache.get<String>(
      key: 'fresh_key',
      fetcher: () async => 'fresh_data',
    );
    try {
      await devCache.get<String>(
        key: 'error_key',
        fetcher: () async => throw Exception('err'),
      );
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 50));

    expect(eventTypes, contains(CacheEventType.hit));
    expect(eventTypes, contains(CacheEventType.miss));
    expect(eventTypes, contains(CacheEventType.fetch));
    expect(eventTypes, contains(CacheEventType.error));

    await sub.cancel();
  });

  test('production mode has zero overhead', () async {
    final events = <CacheEvent>[];
    prodCache.events.listen(events.add);

    await prodCache.set(key: 'prod', data: 'data');
    await prodCache.get<String>(
      key: 'prod',
      fetcher: () async => 'new_data',
    );

    await Future.delayed(const Duration(milliseconds: 20));

    expect(events, isEmpty);
    expect(prodCache.stats.hits, 0);
    expect(prodCache.stats.misses, 0);
    expect(prodCache.stats.fetches, 0);
  });
}
