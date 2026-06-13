import 'package:smart_cache/smart_cache.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    test('should not be expired when ttl is null', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now(),
        ttl: null,
      );
      expect(entry.isExpired, isFalse);
    });

    test('should be expired when ttl is passed', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now().subtract(Duration(minutes: 10)),
        ttl: Duration(minutes: 5),
      );
      expect(entry.isExpired, isTrue);
    });

    test('should not be expired when ttl is not yet reached', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now().subtract(Duration(minutes: 2)),
        ttl: Duration(minutes: 5),
      );
      expect(entry.isExpired, isFalse);
    });
  });

  group('SmartCacheManager', () {
    late SmartCacheManager cache;
    late MemoryCacheStorage storage;

    setUp(() {
      NetworkStatus.setMockStatus(true);
      storage = MemoryCacheStorage();
      cache = SmartCacheManager(memoryStorage: storage);
    });

    test('set and get should work correctly', () async {
      await cache.set(key: 'key1', data: 'value1');
      final result = await cache.get(
        key: 'key1',
        fetcher: () async => 'fetched',
      );
      expect(result, 'value1');
    });

    test('get should call fetcher on cache miss', () async {
      var fetchCount = 0;
      final result = await cache.get(
        key: 'missing',
        fetcher: () async {
          fetchCount++;
          return 'fetched';
        },
      );
      expect(result, 'fetched');
      expect(fetchCount, 1);
    });

    test('get should call fetcher and update cache when expired', () async {
      await cache.set(
        key: 'expired_key',
        data: 'old_value',
        ttl: Duration(milliseconds: 1),
      );

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      var fetchCount = 0;
      final result = await cache.get(
        key: 'expired_key',
        fetcher: () async {
          fetchCount++;
          return 'new_value';
        },
      );

      expect(result, 'new_value');
      expect(fetchCount, 1);

      // Verify it's updated in storage
      final entry = await storage.read('expired_key');
      expect(entry?.data, 'new_value');
    });

    test('delete should remove item from cache', () async {
      await cache.set(key: 'key1', data: 'value1');
      await cache.delete('key1');

      var fetchCount = 0;
      final result = await cache.get(
        key: 'key1',
        fetcher: () async {
          fetchCount++;
          return 'fetched';
        },
      );
      expect(result, 'fetched');
      expect(fetchCount, 1);
    });

    test('clear should remove all items', () async {
      await cache.set(key: 'key1', data: 'value1');
      await cache.set(key: 'key2', data: 'value2');
      await cache.clear();

      final entry1 = await storage.read('key1');
      final entry2 = await storage.read('key2');

      expect(entry1, isNull);
      expect(entry2, isNull);
    });

    test('get should throw exception if fetcher returns null', () async {
      expect(
        () => cache.get<String?>(
          key: 'key',
          fetcher: () async => null,
        ),
        throwsException,
      );
    });

    group('Phase 2: Cache Policies', () {
      test('cacheFirst: returns cache if available and not expired', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.cacheFirst,
        );
        expect(result, 'cached_value');
        expect(fetchCount, 0);
      });

      test('cacheFirst: fetches if cache is missing', () async {
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.cacheFirst,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });

      test('networkFirst: returns fetched data on success', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.networkFirst,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);

        // Verify cache updated
        final entry = await storage.read('key');
        expect(entry?.data, 'fetched_value');
      });

      test('networkFirst: falls back to cache on fetch error', () async {
        await cache.set(key: 'key', data: 'cached_value');
        final result = await cache.get<String>(
          key: 'key',
          fetcher: () async => throw Exception('Fetch failed'),
          policy: CachePolicy.networkFirst,
        );
        expect(result, 'cached_value');
      });

      test('cacheOnly: returns cache if exists', () async {
        await cache.set(key: 'key', data: 'cached_value');
        final result = await cache.get(
          key: 'key',
          fetcher: () async => 'fetched',
          policy: CachePolicy.cacheOnly,
        );
        expect(result, 'cached_value');
      });

      test('cacheOnly: throws exception if cache missing', () async {
        expect(
          () => cache.get(
            key: 'missing',
            fetcher: () async => 'fetched',
            policy: CachePolicy.cacheOnly,
          ),
          throwsException,
        );
      });

      test('networkOnly: always fetches', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.networkOnly,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });
    });

    group('Phase 2: Request Deduplication', () {
      test('multiple concurrent calls return the same future', () async {
        var fetchCount = 0;
        final f1 = cache.get(
          key: 'key',
          fetcher: () async {
            await Future.delayed(Duration(milliseconds: 50));
            fetchCount++;
            return 'fetched_value';
          },
        );
        final f2 = cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value_2';
          },
        );

        final results = await Future.wait([f1, f2]);
        expect(results[0], 'fetched_value');
        expect(results[1], 'fetched_value');
        expect(fetchCount, 1);
      });
    });

    group('Phase 2: Stale-While-Revalidate (SWR)', () {
      test('returns cached data immediately and refreshes in background', () async {
        await cache.set(key: 'key', data: 'stale_value');

        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            await Future.delayed(Duration(milliseconds: 20));
            fetchCount++;
            return 'fresh_value';
          },
          policy: CachePolicy.staleWhileRevalidate,
        );

        expect(result, 'stale_value');
        expect(fetchCount, 0);

        // Wait for background refresh
        await Future.delayed(Duration(milliseconds: 50));
        expect(fetchCount, 1);

        // Next call should get fresh data
        final nextResult = await cache.get(
          key: 'key',
          fetcher: () async => 'even_fresher',
          policy: CachePolicy.cacheFirst,
        );
        expect(nextResult, 'fresh_value');
      });

      test('behaves like cacheFirst if cache is missing', () async {
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.staleWhileRevalidate,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });
    });
  });
}
