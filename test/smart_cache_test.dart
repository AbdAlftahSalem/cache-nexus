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
      storage = MemoryCacheStorage();
      cache = SmartCacheManager(storage: storage);
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
  });
}
