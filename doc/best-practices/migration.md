# Migration Guide

Side-by-side comparisons for migrating from other caching solutions to Smart Cache.

---

## From Hive

### Before (Hive only)

```dart
import 'package:hive_flutter/hive_flutter.dart';

await Hive.initFlutter();
final box = await Hive.openBox('cache');

// Set
await box.put('users', users);

// Get
final users = box.get('users');

// Delete
await box.delete('users');
```

### After (Smart Cache)

```dart
import 'package:cache_nexus/cache_nexus.dart';

final hiveStorage = HiveCacheStorage(boxName: 'cache');
await hiveStorage.init();

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);

// Set
await cache.set<List<User>>(key: 'users', data: users);

// Get (with auto-fetch on miss)
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
);

// Delete
await cache.delete( 'users');
```

### Benefits

- Automatic TTL expiration
- In-memory cache for fast reads
- Cache policies (cacheFirst, networkFirst, etc.)
- Request deduplication
- Reactive streams

---

## From shared_preferences

### Before (shared_preferences)

```dart
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();

// Set
await prefs.setString('token', 'abc123');
await prefs.setStringList('users', ['Alice', 'Bob']);

// Get
final token = prefs.getString('token');
final users = prefs.getStringList('users');

// Delete
await prefs.remove('token');
```

### After (Smart Cache)

```dart
import 'package:cache_nexus/cache_nexus.dart';

final hiveStorage = HiveCacheStorage(boxName: 'prefs');
await hiveStorage.init();

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);

// Set
await cache.set<String>(key: 'token', data: 'abc123');
await cache.set<List<String>>(key: 'users', data: ['Alice', 'Bob']);

// Get
final token = await cache.get<String>(
  key: 'token',
  fetcher: () => null,
);
final users = await cache.get<List<String>>(
  key: 'users',
  fetcher: () => [],
);

// Delete
await cache.delete( 'token');
```

### Benefits

- Type-safe (no type casting needed)
- TTL support
- Automatic fetch on cache miss
- Reactive streams

---

## From Riverpod

### Before (Riverpod)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final usersProvider = FutureProvider<List<User>>((ref) async {
  final response = await http.get(Uri.parse('https://api.example.com/users'));
  return jsonDecode(response.body);
});

// Usage
ref.watch(usersProvider);
```

### After (Smart Cache)

```dart
import 'package:cache_nexus/cache_nexus.dart';

final cacheProvider = Provider<CacheNexusManager>((ref) {
  return CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
  );
});

final usersProvider = FutureProvider<List<User>>((ref) async {
  final cache = ref.watch(cacheProvider);
  return cache.get<List<User>>(
    key: 'users',
    fetcher: () async {
      final response = await http.get(Uri.parse('https://api.example.com/users'));
      return jsonDecode(response.body);
    },
    ttl: const Duration(minutes: 30),
  );
});

// Usage
ref.watch(usersProvider);
```

### Benefits

- Built-in persistence
- TTL support
- Cache policies
- Dev tools

---

## From Dio Cache

### Before (Dio Cache)

```dart
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

final cacheStore = MemCacheStore(maxSize: 1048576, maxEntrySize: 52428);
final cacheOptions = CacheOptions(
  store: cacheStore,
  policy: CachePolicy.forceCache,
  maxStale: const Duration(days: 7),
);

final dio = Dio()..interceptors.add(DioCacheInterceptor(options: cacheOptions));
```

### After (Smart Cache)

```dart
import 'package:cache_nexus/cache_nexus.dart';

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
);

final dio = Dio()..interceptors.add(CacheNexusDioInterceptor(cache));

// Usage
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () async {
    final response = await dio.get('/users');
    return response.data;
  },
  ttl: const Duration(minutes: 30),
  policy: CachePolicy.cacheFirst,
);
```

### Benefits

- Two-tier storage (memory + disk)
- Cache policies
- Auth-aware caching
- Reactive streams
- Dev tools

---

## Migration Checklist

- [ ] Replace storage initialization
- [ ] Update cache set/get calls
- [ ] Add TTL to cache entries
- [ ] Choose appropriate cache policies
- [ ] Add error handling
- [ ] Test cache behavior
- [ ] Enable dev mode for debugging
- [ ] Monitor cache stats

---

## Next

- [Architecture](architecture.md)
- [Error Handling](error-handling.md)
- [Performance](performance.md)
