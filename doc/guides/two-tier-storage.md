# Two-Tier Storage

Cache Nexus uses a **memory-first** architecture with optional persistent storage. This gives you the best of both worlds: speed and durability.

---

## How It Works

```
┌─────────────────────────────────────────┐
│              CacheNexusManager           │
│                                          │
│  Read:  Memory → Persistent → Restore    │
│  Write: Memory + Persistent              │
│  Delete: Memory + Persistent             │
└─────────────────────────────────────────┘
```

1. **Read**: Check memory first. If miss, check persistent storage. If found in persistent, restore to memory.
2. **Write**: Write to both memory and persistent storage.
3. **Delete**: Delete from both tiers.

---

## MemoryCacheStorage

In-memory `Map`-based storage. Fastest option, lost on app restart.

### Usage

```dart
final memoryStorage = MemoryCacheStorage();

final cache = CacheNexusManager(
  memoryStorage: memoryStorage,
);
```

### Characteristics

| Feature | Value |
|---------|-------|
| Speed | ⚡ Fastest |
| Persistence | ❌ Lost on restart |
| Memory | Limited by device RAM |
| Thread Safety | ✅ Single-threaded |

### When to use

- Default for all apps
- Fast access needed
- Data can be re-fetched
- Testing and development

---

## HiveCacheStorage

Persistent storage backed by [Hive CE](https://pub.dev/packages/hive_ce) (the maintained Hive fork; it reads boxes written by Hive 2.x, so data cached by cache_nexus 1.0 is kept). Survives app restarts.

Keys longer than Hive's 255-byte limit (long URLs, long Arabic keys) are stored under a SHA-256 based key automatically; prefix deletes such as `invalidateByContext` still find them.

If your app initialises Hive itself, use Hive CE (`import 'package:hive_ce_flutter/hive_flutter.dart'; await Hive.initFlutter();`) and pass `init(initHive: false)`. If Hive CE turns out not to be initialised, `init` calls `Hive.initFlutter()` itself and logs why.

### Usage

```dart
final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
await hiveStorage.init();  // Must initialize before use

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);
```

### Characteristics

| Feature | Value |
|---------|-------|
| Speed | 🔵 Fast |
| Persistence | ✅ Survives restart |
| Memory | Efficient (disk-based) |
| Thread Safety | ✅ Yes |

### When to use

- Data should persist across restarts
- Large datasets
- Offline support needed
- Production apps

---

## Typed data and app restarts

Memory holds your objects as they are. Disk can only hold JSON-like data, so after a restart a cached `Post` comes back as a `Map`. Cache Nexus converts it back for you:

- **Built in:** `String`, `num`, `bool`, `DateTime`, `Map<String, dynamic>`, and the common collections (`List<String>`, `List<int>`, `List<double>`, `List<num>`, `List<bool>`, `List<Map<String, dynamic>>`, `Map<String, String|int|double|num|bool>`, `Set<String>`, `Set<int>`) plus their nullable variants.
- **Your classes:** register a `CacheAdapter` once. It also covers `List<T>`, `Map<String, T>` and `T?`.

```dart
cache.registerAdapter<Post>(
  CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
);

// Survives restarts, works offline:
final posts = await cache.get<List<Post>>(key: 'posts', fetcher: api.getPosts);
```

Or implement the interface yourself:

```dart
class PostAdapter extends CacheAdapter<Post> {
  @override
  Post fromData(dynamic data) => Post.fromJson(data as Map<String, dynamic>);

  @override
  dynamic toData(Post value) => value.toJson();
}
```

`fromData` only runs for data read back from disk (memory hits return your object directly), and it always receives `Map<String, dynamic>` / `List<dynamic>`.

Without an adapter, a stored custom class cannot be rebuilt: the entry counts as a miss, a `CacheDecodeException` error event is emitted and, in debug builds, a log line names the adapter to register. For offline-first data (todos, drafts) that would mean the fetcher runs and its result replaces what was on disk, so **always register adapters for the types you persist**.

> `TypeAdapter` (the 1.0 name) still works but is deprecated: it clashes with Hive's own `TypeAdapter`. Use `CacheAdapter`.

---

## SecureCacheStorage

Decorator that adds encryption and compression to any storage backend.

### Usage

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),  // or HiveCacheStorage
  encryptor: AesGcmEncryptor.fromBase64(encryptionKey), // from secure storage
  compressor: const GZipCompressor(),
);

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### Characteristics

| Feature | Value |
|---------|-------|
| Speed | 🟡 Slower (encryption overhead) |
| Persistence | Depends on inner storage |
| Security | ✅ Encrypted |
| Compression | ✅ Reduces size |

### When to use

- Sensitive data (tokens, personal info)
- Compliance requirements (GDPR, HIPAA)
- Large data that needs compression

---

## Combining Storages

### Memory + Hive (Recommended)

Best balance of speed and persistence:

```dart
final hiveStorage = HiveCacheStorage(boxName: 'cache');
await hiveStorage.init();

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),     // Fast access
  persistentStorage: hiveStorage,
);
```

### Memory + Secure Hive

For sensitive data:

```dart
final hiveStorage = HiveCacheStorage(boxName: 'secure_cache');
await hiveStorage.init();

final secureStorage = SecureCacheStorage(
  hiveStorage,
  encryptor: AesGcmEncryptor.fromBase64(encryptionKey), // from secure storage
  compressor: const GZipCompressor(),
);

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### Memory Only (Simple)

For testing or when persistence isn't needed:

```dart
final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
);
```

---

## Example Flow

```dart
// 1. First call: fetches from API, stores in both tiers
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: Duration(minutes: 30),
);
// API called, data in memory + Hive

// 2. Second call: returns from memory (instant)
final users2 = await cache.get<List<User>>(key: 'users');
// No API call, instant from memory

// 3. App restart
final cache2 = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);

// 4. First call after restart: returns from Hive, restores to memory
final users3 = await cache2.get<List<User>>(key: 'users');
// No API call, fast from Hive
```

---

## Performance Comparison

| Operation | Memory Only | Memory + Hive | Memory + Secure Hive |
|-----------|-------------|---------------|----------------------|
| First read | ~1ms | ~5ms | ~10ms |
| Subsequent reads | ~0.1ms | ~0.1ms | ~0.1ms |
| Write | ~0.5ms | ~3ms | ~8ms |
| App restart read | N/A (empty) | ~5ms | ~10ms |

---

## Next Steps

- [Security & Auth](security-auth.md) - Encryption and user isolation
- [Reactive Streams](reactive-streams.md) - Watch API and widgets
- [Offline Sync](offline-sync.md) - SyncEngine for offline-first apps
