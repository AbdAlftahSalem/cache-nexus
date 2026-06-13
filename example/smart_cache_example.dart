import 'package:smart_cache/smart_cache.dart';

void main() async {
  // 1. Initialize storage
  final storage = MemoryCacheStorage();

  // 2. Initialize manager
  final cache = SmartCacheManager(memoryStorage: storage);

  // 3. Phase 4: Persistent Storage (Hive) - Demonstration of setup
  // Note: In a real app, you would call:
  // final persistentStorage = HiveCacheStorage();
  // await persistentStorage.init();
  // final cacheWithPersistence = SmartCacheManager(persistentStorage: persistentStorage);

  // 4. Use the cache
  print('--- Fetching users (first time, should call fetcher) ---');
  final users = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async {
      print('Calling API to fetch users...');
      return ['Alice', 'Bob', 'Charlie'];
    },
    ttl: Duration(minutes: 5),
  );
  print('Users: $users');

  print('\n--- Fetching users again (should return cached data) ---');
  final cachedUsers = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async {
      print('Calling API (this should NOT be printed)...');
      return [];
    },
  );
  print('Cached Users: $cachedUsers');

  print('\n--- Deleting users and fetching again ---');
  await cache.delete('users');
  final usersAfterDelete = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async {
      print('Calling API (should be printed again)...');
      return ['Dave', 'Eve'];
    },
  );
  print('Users after delete: $usersAfterDelete');

  print('\n--- Clearing cache ---');
  await cache.clear();
}
