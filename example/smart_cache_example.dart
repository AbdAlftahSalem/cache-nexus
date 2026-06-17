import 'package:smart_cache/smart_cache.dart';

void main() async {
  // 1. Initialize storage
  final memoryStorage = MemoryCacheStorage();

  // 2. Phase 5: Security & Compression Layer
  // Wrap your persistent storage (like Hive) with SecureCacheStorage
  final securePersistentStorage = SecureCacheStorage(
    MemoryCacheStorage(), // In real app, use HiveCacheStorage()
    encryptor: SimpleEncryptor('enterprise_secret_key'),
    compressor: SimpleCompressor(),
  );

  // 3. Initialize manager with security and context
  final cache = SmartCacheManager(
    memoryStorage: memoryStorage,
    persistentStorage: securePersistentStorage,
  );

  // 4. Phase 5: Auth-Aware Caching
  print('--- User A Session ---');
  cache.setContext(const CacheContext(userId: 'user_123', role: 'admin'));

  await cache.get<String>(
    key: 'secret_data',
    fetcher: () async => 'Top Secret Admin Info',
  );
  print('Stored secret_data for User A');

  // 5. Switch User
  print('\n--- User B Session (Isolation) ---');
  cache.setContext(const CacheContext(userId: 'user_456', role: 'guest'));

  final guestData = await cache.get<String>(
    key: 'secret_data',
    fetcher: () async {
      print('User B cannot see User A data. Fetching new data...');
      return 'Public Guest Info';
    },
  );
  print('Data for User B: $guestData');

  // 6. Verification of Secure Storage
  print('\n--- Smart Invalidation ---');
  print('Invalidating User A cache only...');
  await cache.invalidateByContext(const CacheContext(userId: 'user_123'));

  print('\n--- Use the cache (Phase 1-4 features still work) ---');
  final users = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async {
      print('Calling API to fetch users...');
      return ['Alice', 'Bob', 'Charlie'];
    },
    ttl: Duration(minutes: 5),
  );
  print('Users: $users');

  await cache.clear();
  print('Cache cleared.');
}
