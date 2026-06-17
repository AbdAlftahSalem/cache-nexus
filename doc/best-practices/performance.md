# Performance

Tips for optimizing Smart Cache performance.

---

## TTL Tuning

### Short TTL (5-15 minutes)

For frequently changing data:

```dart
await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  ttl: const Duration(minutes: 5),
);
```

### Medium TTL (1-6 hours)

For moderately changing data:

```dart
await cache.get<User>(
  key: 'profile',
  fetcher: () => api.getProfile(),
  ttl: const Duration(hours: 1),
);
```

### Long TTL (24+ hours)

For rarely changing data:

```dart
await cache.get<List<Category>>(
  key: 'categories',
  fetcher: () => api.getCategories(),
  ttl: const Duration(hours: 24),
);
```

### No TTL (null)

For persistent data:

```dart
await cache.set<String>(
  key: 'auth_token',
  data: token,
  ttl: null, // Never expires
);
```

---

## Key Naming

### Use Descriptive Keys

```dart
// Bad
await cache.set(key: 'a', data: '1');

// Good
await cache.set(key: 'user_profile_123', data: user);
await cache.set(key: 'posts_page_1', data: posts);
```

### Use Prefixes for Groups

```dart
// User-specific data
await cache.set(key: 'user_123_profile', data: profile);
await cache.set(key: 'user_123_settings', data: settings);

// Delete all user data
await cache.memoryStorage.deleteByPrefix('user_123_');
```

### Avoid Long Keys

```dart
// Bad: long key
await cache.set(
  key: 'user_123_posts_page_1_filter_all_sort_by_date',
  data: posts,
);

// Good: shorter key
await cache.set(key: 'u123_posts', data: posts);
```

---

## Memory Management

### Limit Cache Size

```dart
// Monitor cache stats
print('Hits: ${cache.stats.hits}');
print('Misses: ${cache.stats.misses}');
print('Hit Rate: ${cache.stats.hitRate}');

// Clear old data periodically
if (cache.stats.hits > 1000) {
  await cache.clear();
}
```

### Use Two-Tier Storage

```dart
final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),  // Fast, limited
  persistentStorage: hiveStorage,        // Slow, unlimited
);
```

### Evict Old Entries

```dart
// Delete entries by prefix
await cache.memoryStorage.deleteByPrefix('old_data_');

// Delete specific entries
await cache.delete( 'temporary_data');
```

---

## Request Deduplication

Smart Cache automatically deduplicates concurrent requests:

```dart
// These 3 calls happen simultaneously
final f1 = cache.get<List<User>>(key: 'users', fetcher: () => api.getUsers());
final f2 = cache.get<List<User>>(key: 'users', fetcher: () => api.getUsers());
final f3 = cache.get<List<User>>(key: 'users', fetcher: () => api.getUsers());

// Only ONE API call is made
final results = await Future.wait([f1, f2, f3]);
```

---

## Debounce Reactive Streams

Prevent rapid UI rebuilds:

```dart
// Without debounce (bad)
cache.watch<List<Product>>('products').listen((products) {
  setState(() => _products = products);
});

// With debounce (good)
cache.watch<List<Product>>(
  'products',
  debounce: const Duration(milliseconds: 300),
).listen((products) {
  setState(() => _products = products);
});
```

---

## Production Mode

Disable dev features in production:

```dart
final cache = CacheNexusManager(
  mode: kReleaseMode ? CacheNexusMode.production : CacheNexusMode.dev,
);
```

In production mode:
- No events are created
- Stats are not tracked
- Overlay widget renders just the child
- Zero performance overhead

---

## Benchmarking

```dart
import 'dart:developer' as developer;

Future<void> benchmarkCache() async {
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
  );

  // Benchmark set
  final sw = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    await cache.set<String>(key: 'key_$i', data: 'value_$i');
  }
  sw.stop();
  print('Set 1000 entries: ${sw.elapsedMilliseconds}ms');

  // Benchmark get (hits)
  sw.reset();
  sw.start();
  for (int i = 0; i < 1000; i++) {
    await cache.get<String>(key: 'key_$i', fetcher: () => null);
  }
  sw.stop();
  print('Get 1000 hits: ${sw.elapsedMilliseconds}ms');

  // Benchmark get (misses)
  sw.reset();
  sw.start();
  for (int i = 0; i < 1000; i++) {
    await cache.get<String>(key: 'miss_$i', fetcher: () async => 'data');
  }
  sw.stop();
  print('Get 1000 misses: ${sw.elapsedMilliseconds}ms');
}
```

---

## Tips Summary

| Tip | Benefit |
|-----|---------|
| Use appropriate TTL | Balance freshness vs performance |
| Use descriptive keys | Easier debugging and invalidation |
| Use two-tier storage | Fast memory + persistent disk |
| Enable debouncing | Prevent UI lag |
| Use production mode | Zero overhead in release |
| Monitor cache stats | Identify bottlenecks |

---

## Next

- [Migration](migration.md)
