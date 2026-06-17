# Common Issues

Frequently encountered problems and solutions.

---

## Cache Not Persisting

**Problem:** Data disappears after app restart.

**Solution:** Add persistent storage:

```dart
final hiveStorage = HiveCacheStorage(boxName: 'cache');
await hiveStorage.init(); // Don't forget to initialize!

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage, // Add this
);
```

---

## Cache Not Expiring

**Problem:** Data doesn't expire after TTL.

**Solution:** Ensure TTL is set correctly:

```dart
// Bad: no TTL
await cache.get<String>(key: 'data', fetcher: () => 'hello');

// Good: with TTL
await cache.get<String>(
  key: 'data',
  fetcher: () => 'hello',
  ttl: const Duration(hours: 1),
);
```

---

## fetcher Not Called

**Problem:** fetcher is not called on cache miss.

**Solution:** Check cache policy:

```dart
// Bad: cacheOnly never calls fetcher
await cache.get<String>(
  key: 'data',
  fetcher: () => 'hello',
  policy: CachePolicy.cacheOnly,
);

// Good: cacheFirst calls fetcher on miss
await cache.get<String>(
  key: 'data',
  fetcher: () => 'hello',
  policy: CachePolicy.cacheFirst,
);
```

---

## Multiple Fetches for Same Key

**Problem:** Multiple API calls for the same key.

**Solution:** Use concurrent requests (Smart Cache deduplicates):

```dart
// These will deduplicate (only 1 API call)
final f1 = cache.get<String>(key: 'data', fetcher: () => api.getData());
final f2 = cache.get<String>(key: 'data', fetcher: () => api.getData());
final f3 = cache.get<String>(key: 'data', fetcher: () => api.getData());
await Future.wait([f1, f2, f3]);
```

---

## UI Not Updating

**Problem:** UI doesn't update when cache changes.

**Solution:** Use SmartCacheBuilder or watch():

```dart
// Bad: manual setState
final data = await cache.get<String>(key: 'data', fetcher: () => null);
setState(() => _data = data);

// Good: SmartCacheBuilder
SmartCacheBuilder<String>(
  cache: cache,
  cacheKey: 'data',
  builder: (context, data) {
    return Text(data ?? 'No data');
  },
);
```

---

## Auth Data Leaking Between Users

**Problem:** User A sees User B's data.

**Solution:** Set context for each user:

```dart
// Bad: no context
await cache.get<String>(key: 'profile', fetcher: () => api.getProfile());

// Good: with context
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
await cache.get<String>(key: 'profile', fetcher: () => api.getProfile());
```

---

## SecureCacheStorage Not Working

**Problem:** Data is not encrypted.

**Solution:** Ensure you're using SecureCacheStorage correctly:

```dart
// Bad: wrapping wrong storage
final secure = SecureCacheStorage(
  MemoryCacheStorage(), // This is the inner storage
  encryptor: SimpleEncryptor('key'),
);

// Good: wrapping persistent storage
final hiveStorage = HiveCacheStorage(boxName: 'cache');
await hiveStorage.init();

final secure = SecureCacheStorage(
  hiveStorage, // Wrap the persistent storage
  encryptor: SimpleEncryptor('key'),
);
```

---

## SyncEngine Not Processing Tasks

**Problem:** Queued tasks are not being processed.

**Solution:** Ensure SyncEngine is initialized and connected:

```dart
final syncEngine = SyncEngine(
  executor: (task) async {
    // Your sync logic
    return true;
  },
);
await syncEngine.init(); // Don't forget to initialize!

cache.syncEngine = syncEngine; // Connect to cache
```

---

## Dev Tools Not Showing

**Problem:** Floating debug button doesn't appear.

**Solution:** Enable dev mode:

```dart
// Bad: production mode (default)
final cache = SmartCacheManager();

// Good: dev mode
final cache = SmartCacheManager(
  mode: SmartCacheMode.dev,
);
```

---

## Performance Issues

**Problem:** Cache is slow.

**Solution:** Check these common causes:

1. **Using SecureCacheStorage for non-sensitive data:**
   ```dart
   // Bad: encryption overhead for non-sensitive data
   final cache = SmartCacheManager(
     persistentStorage: SecureCacheStorage(hiveStorage, ...),
   );

   // Good: use plain Hive for non-sensitive data
   final cache = SmartCacheManager(
     persistentStorage: hiveStorage,
   );
   ```

2. **Missing in-memory cache:**
   ```dart
   // Bad: only persistent storage
   final cache = SmartCacheManager(
     persistentStorage: hiveStorage,
   );

   // Good: two-tier storage
   final cache = SmartCacheManager(
     memoryStorage: MemoryCacheStorage(),
     persistentStorage: hiveStorage,
   );
   ```

3. **Using production mode in development:**
   ```dart
   // Bad: no dev tools
   final cache = SmartCacheManager(
     mode: SmartCacheMode.production,
   );

   // Good: dev mode for debugging
   final cache = SmartCacheManager(
     mode: SmartCacheMode.dev,
   );
   ```

---

## Next

- [Troubleshooting](troubleshooting.md)
- [Glossary](glossary.md)
