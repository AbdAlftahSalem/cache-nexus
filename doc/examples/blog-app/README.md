# Blog App Example

A complete blog app demonstrating Cache Nexus features with Dio for network requests.

## Features Demonstrated

- **Cache Policies**: All 5 strategies (cacheFirst, networkFirst, cacheOnly, networkOnly, staleWhileRevalidate)
- **Reactive Streams**: watch() API for auto-updating UI
- **Auth-Aware Isolation**: User/role-based cache key isolation
- **Security Layer**: Encryption + compression decorators
- **Offline Sync**: Persistent queue with automatic retry
- **Dev Tools**: Live events, stats, hit rate tracking

## Screens

| Screen | Description |
|--------|-------------|
| **Home** | Overview of all features |
| **Policies** | Test all 5 cache policies |
| **Reactive** | Watch cache updates in real-time |
| **Auth** | User context switching and isolation |
| **Security** | Encryption and decryption demo |
| **Sync** | Offline task queue with mock online/offline |
| **Stats** | Live cache events and statistics |

## Key Code

### Cache Initialization

```dart
final memoryStorage = MemoryCacheStorage();
final securePersistentStorage = SecureCacheStorage(
  MemoryCacheStorage(),
  encryptor: AesGcmEncryptor.fromBase64(encryptionKey), // from secure storage
  compressor: const GZipCompressor(),
);

final cache = CacheNexusManager(
  memoryStorage: memoryStorage,
  persistentStorage: securePersistentStorage,
  mode: CacheNexusMode.dev,
);
```

### Using Different Policies

```dart
// Cache first (default)
final posts = await cache.get<List<Post>>(
  key: 'posts',
  fetcher: () => api.getPosts(),
  ttl: Duration(minutes: 5),
  policy: CachePolicy.cacheFirst,
);

// Network first
final posts = await cache.get<List<Post>>(
  key: 'posts',
  fetcher: () => api.getPosts(),
  policy: CachePolicy.networkFirst,
);
```

### Auth-Aware Caching

```dart
// Set user context
cache.setContext(CacheContext(
  userId: 'user_123',
  role: 'admin',
));

// Cache keys are now scoped: u8:user_123|r5:admin|posts
final posts = await cache.get<List<Post>>(key: 'posts', fetcher: () => ...);

// Switch user
cache.setContext(CacheContext(
  userId: 'user_456',
  role: 'guest',
));

// Different cache keys: user_456_guest_posts
final guestPosts = await cache.get<List<Post>>(key: 'posts', fetcher: () => ...);
```

### Offline Sync

```dart
await cache.enqueueSyncTask(SyncTask(
  id: 'create_post_${DateTime.now().millisecondsSinceEpoch}',
  key: 'post_new',
  endpoint: 'https://jsonplaceholder.typicode.com/posts',
  method: 'POST',
  body: post.toJson(),
  createdAt: DateTime.now(),
));
```

## Running

```bash
flutter run
```

## Dependencies

- `cache_nexus`: The cache package
- `dio`: HTTP client
- `hive_ce_flutter`: Persistent storage (via cache_nexus)
- `connectivity_plus`: Network status monitoring
