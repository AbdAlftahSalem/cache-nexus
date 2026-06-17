# Glossary

Smart Cache terminology and definitions.

---

## A

### Auth-Aware Caching

Cache key isolation by user ID and role. Different users never see each other's cached data.

```dart
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
```

---

## C

### Cache Entry

A wrapper for cached data that includes metadata like creation time and TTL.

```dart
CacheEntry(
  data: 'hello',
  createdAt: DateTime.now(),
  ttl: const Duration(hours: 1),
)
```

### Cache Hit

When requested data is found in the cache (no network fetch needed).

### Cache Miss

When requested data is not found in the cache (network fetch needed).

### Cache Policy

Strategy for how to handle cache reads and writes. Smart Cache supports 5 policies:

- `cacheFirst`
- `networkFirst`
- `cacheOnly`
- `networkOnly`
- `staleWhileRevalidate`

### Cache Stats

Metrics tracking cache performance: hits, misses, fetches, errors, hit rate.

### CacheStorage

Interface for storage backends. Implementations:

- `MemoryCacheStorage`
- `HiveCacheStorage`
- `SecureCacheStorage`

---

## D

### Debounce

Delaying updates to prevent rapid UI rebuilds during fast cache changes.

```dart
cache.watch<List<Product>>(
  'products',
  debounce: const Duration(milliseconds: 300),
);
```

### Dev Mode

Development mode that enables debug tools (events, stats, overlay).

```dart
SmartCacheMode.dev
```

---

## H

### Hit Rate

Ratio of cache hits to total requests (hits + misses).

```dart
cache.stats.hitRate // 0.0 to 1.0
```

### HiveCacheStorage

Persistent storage backend using Hive. Survives app restarts.

---

## M

### MemoryCacheStorage

In-memory storage backend using a Map. Fastest option, lost on app restart.

### Mock Status

Simulated network status for testing.

```dart
NetworkStatus.setMockStatus(false); // Force offline
```

---

## N

### Network Status

Detection of device connectivity. Used by SyncEngine for offline support.

```dart
final isOnline = await NetworkStatus.isOnline;
```

---

## P

### Production Mode

Mode that disables all dev features for release builds.

```dart
SmartCacheMode.production
```

---

## S

### SecureCacheStorage

Decorator that adds encryption and compression to any storage backend.

```dart
SecureCacheStorage(
  innerStorage,
  encryptor: SimpleEncryptor('key'),
  compressor: SimpleCompressor(),
)
```

### SmartCacheBuilder

Flutter widget that automatically rebuilds when a cache key changes.

```dart
SmartCacheBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserList(users: users),
)
```

### SmartCacheManager

Central class that orchestrates all caching operations.

```dart
final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: HiveCacheStorage(boxName: 'cache'),
);
```

### Stale While Revalidate

Cache policy that returns cached data instantly, then refreshes in the background.

```dart
CachePolicy.staleWhileRevalidate
```

### SyncEngine

Offline sync queue for persistent task execution.

```dart
final syncEngine = SyncEngine(
  executor: (task) async {
    // Execute task
    return true;
  },
);
```

### Sync Task

A queued task for offline execution.

```dart
SyncTask(
  id: 'task_1',
  key: 'data',
  endpoint: 'https://api.example.com/data',
  method: 'POST',
  body: {'key': 'value'},
  createdAt: DateTime.now(),
)
```

---

## T

### Two-Tier Storage

Architecture using fast in-memory storage (Layer 1) and persistent disk storage (Layer 2).

```dart
SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),    // Layer 1
  persistentStorage: hiveStorage,         // Layer 2
)
```

### TTL (Time-to-Live)

Duration after which a cache entry expires.

```dart
await cache.get<String>(
  key: 'data',
  fetcher: () => 'hello',
  ttl: const Duration(hours: 1), // Expires after 1 hour
);
```

---

## W

### Watch

Subscribe to cache key changes.

```dart
cache.watch<List<User>>('users').listen((users) {
  print('Users updated: ${users?.length}');
});
```

---

## Related

- [Core Concepts](../guides/core-concepts.md)
- [Cache Policies](../guides/cache-policies.md)
- [API Reference](../api/)
