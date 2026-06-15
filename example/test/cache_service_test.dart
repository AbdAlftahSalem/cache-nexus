import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';
import 'package:smart_cache_example/models/post.dart';
import 'package:smart_cache_example/services/api_service.dart';

void main() {
  late SmartCacheManager cache;
  late MemoryCacheStorage memoryStorage;
  late ApiService apiService;

  setUp(() {
    NetworkStatus.setMockStatus(true);
    memoryStorage = MemoryCacheStorage();
    cache = SmartCacheManager(memoryStorage: memoryStorage, mode: SmartCacheMode.dev);
    apiService = ApiService();
  });

  tearDown(() {
    cache.dispose();
  });

  test('cache wraps Dio response correctly', () async {
    final posts = await cache.get<List<Post>>(
      key: 'test_posts',
      fetcher: () async {
        return [
          Post(id: 1, userId: 1, title: 'Cached Post', body: 'Body'),
        ];
      },
      ttl: const Duration(minutes: 5),
    );

    expect(posts.length, 1);
    expect(posts[0].title, 'Cached Post');

    final entry = await memoryStorage.read('test_posts');
    expect(entry, isNotNull);
  });

  test('cache TTL expiration triggers refetch', () async {
    await cache.set(
      key: 'ttl_test',
      data: 'old_value',
      ttl: const Duration(milliseconds: 1),
    );

    await Future.delayed(const Duration(milliseconds: 10));

    var fetchCount = 0;
    final result = await cache.get<String>(
      key: 'ttl_test',
      fetcher: () async {
        fetchCount++;
        return 'new_value';
      },
    );

    expect(result, 'new_value');
    expect(fetchCount, 1);
  });

  test('cache stores in both memory and persistent', () async {
    final persistent = MemoryCacheStorage();
    final manager = SmartCacheManager(
      memoryStorage: memoryStorage,
      persistentStorage: persistent,
    );

    await manager.set(key: 'both_tiers', data: 'tier_data');

    final memEntry = await memoryStorage.read('both_tiers');
    final persEntry = await persistent.read('both_tiers');

    expect(memEntry?.data, 'tier_data');
    expect(persEntry?.data, 'tier_data');

    manager.dispose();
  });

  test('cache context isolation works', () async {
    cache.setContext(const CacheContext(userId: 'user_a'));
    await cache.set(key: 'profile', data: 'Profile A');

    cache.setContext(const CacheContext(userId: 'user_b'));
    await cache.set(key: 'profile', data: 'Profile B');

    cache.setContext(const CacheContext(userId: 'user_a'));
    final a = await cache.get<String>(
      key: 'profile',
      fetcher: () async => 'default',
    );
    expect(a, 'Profile A');

    cache.setContext(const CacheContext(userId: 'user_b'));
    final b = await cache.get<String>(
      key: 'profile',
      fetcher: () async => 'default',
    );
    expect(b, 'Profile B');
  });
}
