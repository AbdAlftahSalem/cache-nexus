# Hello World

The absolute minimal example to get Smart Cache running. Perfect for testing or learning the basics.

---

## Minimal Example

```dart
import 'package:smart_cache/smart_cache.dart';

void main() async {
  // 1. Create cache
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );

  // 2. First call: fetches from API
  final users = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async => ['Alice', 'Bob', 'Charlie'],
  );
  print('Users: $users');

  // 3. Second call: returns from cache (instant!)
  final cachedUsers = await cache.get<List<String>>(
    key: 'users',
    fetcher: () async => ['This will NOT run'],
  );
  print('Cached users: $cachedUsers');

  // 4. Clean up
  await cache.dispose();
}
```

### Output:
```
Users: [Alice, Bob, Charlie]
Cached users: [Alice, Bob, Charlie]
```

---

## One-Liner

For quick testing:

```dart
final cache = SmartCacheManager(memoryStorage: MemoryCacheStorage());
final data = await cache.get<String>(key: 'test', fetcher: () async => 'Hello World!');
print(data); // 'Hello World!'
```

---

## Minimal with Persistent Storage

```dart
import 'package:smart_cache/smart_cache.dart';

void main() async {
  final hiveStorage = HiveCacheStorage(boxName: 'hello_cache');
  await hiveStorage.init();

  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: hiveStorage,
  );

  final data = await cache.get<String>(
    key: 'hello',
    fetcher: () async => 'Hello from Smart Cache!',
    ttl: const Duration(hours: 24),
  );
  print(data);
}
```

---

## What's Happening?

```dart
final data = await cache.get<String>(
  key: 'hello',           // Unique identifier
  fetcher: () async => 'Hello!',  // Called only if cache miss
  ttl: Duration(hours: 24),       // Expires after 24 hours
);
```

| Parameter | Purpose |
|-----------|---------|
| `key` | Unique identifier for this cache entry |
| `fetcher` | Function that returns fresh data (only called on miss) |
| `ttl` | Time-to-live (optional, null = never expires) |

---

## Common Patterns

### Store a value

```dart
await cache.set<String>(key: 'token', data: 'abc123');
```

### Get a value

```dart
final token = await cache.get<String>(key: 'token', fetcher: () => null);
```

### Delete a value

```dart
await cache.delete(key: 'token');
```

### Clear all

```dart
await cache.clear();
```

---

## Next Steps

- [Quick Start](quick-start.md) - Full Flutter example
- [Core Concepts](../guides/core-concepts.md) - Understand the architecture
