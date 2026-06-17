import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';

void main() {
  late SmartCacheManager cache;
  late MemoryCacheStorage storage;

  setUp(() {
    NetworkStatus.setMockStatus(true);
    storage = MemoryCacheStorage();
    cache = SmartCacheManager(memoryStorage: storage);
  });

  tearDown(() {
    cache.dispose();
  });

  group('cacheFirst', () {
    test('returns cached posts', () async {
      await cache.set(key: 'posts', data: 'cached_posts');
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          fetchCount++;
          return 'fetched_posts';
        },
        policy: CachePolicy.cacheFirst,
      );

      expect(result, 'cached_posts');
      expect(fetchCount, 0);
    });

    test('fetches on miss', () async {
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          fetchCount++;
          return 'fetched_posts';
        },
        policy: CachePolicy.cacheFirst,
      );

      expect(result, 'fetched_posts');
      expect(fetchCount, 1);
    });
  });

  group('networkFirst', () {
    test('returns fresh data', () async {
      await cache.set(key: 'posts', data: 'cached_posts');
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          fetchCount++;
          return 'fresh_posts';
        },
        policy: CachePolicy.networkFirst,
      );

      expect(result, 'fresh_posts');
      expect(fetchCount, 1);
    });

    test('falls back to cache on error', () async {
      await cache.set(key: 'posts', data: 'cached_posts');

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async => throw Exception('Network error'),
        policy: CachePolicy.networkFirst,
      );

      expect(result, 'cached_posts');
    });
  });

  group('cacheOnly', () {
    test('returns cached posts', () async {
      await cache.set(key: 'posts', data: 'cached_posts');

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async => 'fetched',
        policy: CachePolicy.cacheOnly,
      );

      expect(result, 'cached_posts');
    });

    test('throws on miss', () async {
      expect(
        () => cache.get<String>(
          key: 'posts',
          fetcher: () async => 'fetched',
          policy: CachePolicy.cacheOnly,
        ),
        throwsException,
      );
    });
  });

  group('networkOnly', () {
    test('always fetches', () async {
      await cache.set(key: 'posts', data: 'cached_posts');
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          fetchCount++;
          return 'fetched_posts';
        },
        policy: CachePolicy.networkOnly,
      );

      expect(result, 'fetched_posts');
      expect(fetchCount, 1);
    });
  });

  group('staleWhileRevalidate', () {
    test('returns stale immediately', () async {
      await cache.set(key: 'posts', data: 'stale_posts');
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          await Future.delayed(const Duration(milliseconds: 20));
          fetchCount++;
          return 'fresh_posts';
        },
        policy: CachePolicy.staleWhileRevalidate,
      );

      expect(result, 'stale_posts');
      expect(fetchCount, 0);
    });

    test('subsequent call returns fresh', () async {
      await cache.set(key: 'posts', data: 'stale_posts');

      await cache.get<String>(
        key: 'posts',
        fetcher: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'fresh_posts';
        },
        policy: CachePolicy.staleWhileRevalidate,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = await cache.get<String>(
        key: 'posts',
        fetcher: () async => 'even_fresher',
        policy: CachePolicy.cacheFirst,
      );

      expect(result, 'fresh_posts');
    });
  });

  group('request deduplication', () {
    test('concurrent calls share fetcher', () async {
      var fetchCount = 0;

      final f1 = cache.get<String>(
        key: 'dedup',
        fetcher: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          fetchCount++;
          return 'fetched';
        },
      );
      final f2 = cache.get<String>(
        key: 'dedup',
        fetcher: () async {
          fetchCount++;
          return 'fetched_2';
        },
      );

      final results = await Future.wait([f1, f2]);
      expect(results[0], 'fetched');
      expect(results[1], 'fetched');
      expect(fetchCount, 1);
    });
  });
}
