# CacheNexusManager

The central class that orchestrates all caching operations.

---

## Import

```dart
import 'package:cache_nexus/cache_nexus.dart';
```

---

## Constructor

```dart
CacheNexusManager({
  CacheStorage? memoryStorage,
  CacheStorage? persistentStorage,
  SyncEngine? syncEngine,
  CacheNexusMode mode = CacheNexusMode.production,
  CacheContext? context,
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `memoryStorage` | `CacheStorage?` | `MemoryCacheStorage()` | In-memory cache |
| `persistentStorage` | `CacheStorage?` | `null` | Persistent storage |
| `syncEngine` | `SyncEngine?` | `null` | Offline sync queue |
| `mode` | `CacheNexusMode` | `CacheNexusMode.production` | Dev or production mode |
| `context` | `CacheContext?` | `null` | Auth context |

---

## Methods

### get

```dart
Future<T> get<T>({
  required String key,
  required Future<T> Function() fetcher,
  Duration? ttl,
  CachePolicy policy = CachePolicy.cacheFirst,
})
```

Get data from cache with the specified policy.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Cache key |
| `fetcher` | `Future<T> Function()` | Function to fetch fresh data |
| `ttl` | `Duration?` | Time-to-live |
| `policy` | `CachePolicy` | Cache strategy |

**Returns:** `Future<T?>` - Cached data or null

**Example:**

```dart
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: const Duration(minutes: 30),
  policy: CachePolicy.cacheFirst,
);
```

---

### set

```dart
Future<void> set<T>({
  required String key,
  required T data,
  Duration? ttl,
})
```

Store data in cache.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Cache key |
| `data` | `T` | Data to store |
| `ttl` | `Duration?` | Time-to-live |

**Example:**

```dart
await cache.set<List<User>>(
  key: 'users',
  data: [User('Alice'), User('Bob')],
  ttl: const Duration(minutes: 30),
);
```

---

### delete

```dart
Future<void> delete(String key)
```

Remove a key from cache.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Cache key to delete |

**Example:**

```dart
await cache.delete( 'users');
```

---

### clear

```dart
Future<void> clear()
```

Remove all cached data.

**Example:**

```dart
await cache.clear();
```

---

### watch

```dart
Stream<T?> watch<T>(String key, {Duration? debounce})
```

Watch a key for changes.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | Cache key to watch |
| `debounce` | `Duration?` | Debounce interval |

**Returns:** `Stream<T?>` - Stream of cache updates

**Example:**

```dart
cache.watch<List<User>>('users').listen((users) {
  if (users != null) {
    print('Users updated: ${users.length}');
  }
});
```

---

### setContext

```dart
void setContext(CacheContext context)
```

Set auth-aware cache context.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `CacheContext` | User context |

**Example:**

```dart
cache.setContext(CacheContext(
  userId: 'user_123',
  role: 'admin',
));
```

---

### clearContext

```dart
void clearContext()
```

Remove current context.

**Example:**

```dart
cache.clearContext();
```

---

### invalidateByContext

```dart
Future<void> invalidateByContext(CacheContext context)
```

Invalidate all keys matching a context prefix.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `CacheContext` | Context to invalidate |

**Example:**

```dart
await cache.invalidateByContext(CacheContext(userId: 'user_123'));
```

---

### enqueueSyncTask

```dart
Future<void> enqueueSyncTask(SyncTask task)
```

Add a task to the offline sync queue.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `task` | `SyncTask` | Task to enqueue |

**Example:**

```dart
await cache.enqueueSyncTask(SyncTask(
  id: 'task_1',
  key: 'users',
  endpoint: 'https://api.example.com/users',
  method: 'POST',
  body: {'name': 'Alice'},
  createdAt: DateTime.now(),
));
```

---

### dispose

```dart
void dispose()
```

Clean up streams and subscriptions.

**Example:**

```dart
cache.dispose();
```

---

## Properties

### events

```dart
Stream<CacheEvent> get events
```

Stream of cache events (dev mode only).

**Example:**

```dart
cache.events.listen((event) {
  print('[${event.type.name}] ${event.key}');
});
```

---

### stats

```dart
CacheStats get stats
```

Current cache statistics.

**Example:**

```dart
print('Hits: ${cache.stats.hits}');
print('Misses: ${cache.stats.misses}');
print('Hit Rate: ${cache.stats.hitRate}');
```

---

### context

```dart
CacheContext? get context
```

Current auth context.

**Example:**

```dart
if (cache.context != null) {
  print('User: ${cache.context!.userId}');
}
```

---

## Related

- [CacheEntry](cache-storage.md)
- [CachePolicy](cache-policy.md)
- [CacheContext](cache-context.md)
- [SyncEngine](sync-engine.md)
