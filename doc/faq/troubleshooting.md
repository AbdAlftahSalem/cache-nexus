# Troubleshooting

Step-by-step debugging guide for Smart Cache issues.

---

## Debug Mode

Enable dev mode to see cache events:

```dart
final cache = SmartCacheManager(
  mode: SmartCacheMode.dev,
);

// Listen to events
cache.events.listen((event) {
  print('[${event.type.name}] ${event.key}');
});
```

---

## Check Cache Stats

Monitor cache performance:

```dart
print('Hits: ${cache.stats.hits}');
print('Misses: ${cache.stats.misses}');
print('Fetches: ${cache.stats.fetches}');
print('Errors: ${cache.stats.errors}');
print('Hit Rate: ${(cache.stats.hitRate * 100).toStringAsFixed(1)}%');
```

---

## Verify Storage

Check if storage is working:

```dart
// Test memory storage
final memory = MemoryCacheStorage();
await memory.write('test', CacheEntry(
  data: 'hello',
  createdAt: DateTime.now(),
));
final result = await memory.read('test');
print('Memory works: ${result?.data}');

// Test Hive storage
final hive = HiveCacheStorage(boxName: 'test');
await hive.init();
await hive.write('test', CacheEntry(
  data: 'hello',
  createdAt: DateTime.now(),
));
final hiveResult = await hive.read('test');
print('Hive works: ${hiveResult?.data}');
```

---

## Test Cache Policies

Verify each policy works correctly:

```dart
// Test cacheFirst
await cache.set<String>(key: 'test', data: 'cached');
final result = await cache.get<String>(
  key: 'test',
  fetcher: () async => 'fetched',
  policy: CachePolicy.cacheFirst,
);
print('cacheFirst: $result'); // Should be 'cached'

// Test networkFirst
final result2 = await cache.get<String>(
  key: 'test',
  fetcher: () async => 'fetched',
  policy: CachePolicy.networkFirst,
);
print('networkFirst: $result2'); // Should be 'fetched'
```

---

## Test Auth Isolation

Verify user isolation works:

```dart
// User A
cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
await cache.set<String>(key: 'data', data: 'admin_data');

// User B
cache.setContext(CacheContext(userId: 'user_2', role: 'guest'));
final result = await cache.get<String>(
  key: 'data',
  fetcher: () async => 'guest_data',
);
print('User B data: $result'); // Should be 'guest_data'

// Switch back to User A
cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
final adminData = await cache.get<String>(
  key: 'data',
  fetcher: () => null,
);
print('User A data: $adminData'); // Should be 'admin_data'
```

---

## Test Network Status

Verify network detection:

```dart
final isOnline = await NetworkStatus.isOnline;
print('Online: $isOnline');

// Mock for testing
NetworkStatus.setMockStatus(false);
final mockOffline = await NetworkStatus.isOnline;
print('Mock offline: $mockOffline'); // Should be false

NetworkStatus.setMockStatus(true);
final mockOnline = await NetworkStatus.isOnline;
print('Mock online: $mockOnline'); // Should be true
```

---

## Test SyncEngine

Verify offline sync works:

```dart
final syncEngine = SyncEngine(
  executor: (task) async {
    print('Executing task: ${task.id}');
    return true;
  },
);
await syncEngine.init();

// Enqueue a task
await cache.enqueueSyncTask(SyncTask(
  id: 'test_task',
  key: 'test',
  endpoint: 'https://api.example.com/test',
  method: 'POST',
  body: {'test': true},
  createdAt: DateTime.now(),
));

// Process queue
await syncEngine.processQueue();
```

---

## Check for Errors

Listen to error events:

```dart
cache.events.listen((event) {
  if (event.type == CacheEventType.error) {
    print('Error: ${event.key}');
    print('Error details: ${event.error}');
  }
});
```

---

## Memory Leak Detection

Check for memory leaks:

```dart
// Create and dispose multiple caches
for (int i = 0; i < 100; i++) {
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );
  await cache.set<String>(key: 'test_$i', data: 'data_$i');
  await cache.dispose();
}

// Check memory usage
print('Memory after dispose: ${ProcessInfo.currentRss}');
```

---

## Performance Profiling

Profile cache operations:

```dart
import 'dart:developer' as developer;

final sw = Stopwatch()..start();
await cache.get<String>(key: 'test', fetcher: () async => 'data');
sw.stop();
print('Get operation: ${sw.elapsedMilliseconds}ms');
```

---

## Common Error Messages

### "CacheStorage not initialized"

**Solution:** Initialize Hive before use:

```dart
final hiveStorage = HiveCacheStorage(boxName: 'cache');
await hiveStorage.init(); // Add this!
```

### "SyncEngine not connected"

**Solution:** Connect SyncEngine to cache:

```dart
cache.syncEngine = syncEngine;
```

### "Context not set"

**Solution:** Set context before user-specific operations:

```dart
cache.setContext(CacheContext(userId: 'user_123'));
```

---

## Still Stuck?

1. Check the [Common Issues](common-issues.md) page
2. Review the [API Reference](../api/)
3. Open an issue on [GitHub](https://github.com/AbdAlftahSalem/smart-cache/issues)

---

## Next

- [Glossary](glossary.md)
- [Common Issues](common-issues.md)
