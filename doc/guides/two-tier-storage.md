# Two-Tier Storage

Smart Cache uses a **memory-first** architecture with optional persistent storage. This gives you the best of both worlds: speed and durability.

---

## How It Works

```
┌─────────────────────────────────────────┐
│              SmartCacheManager           │
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

final cache = SmartCacheManager(
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

Persistent storage backed by [Hive](https://pub.dev/packages/hive). Survives app restarts.

### Usage

```dart
final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
await hiveStorage.init();  // Must initialize before use

final cache = SmartCacheManager(
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

## SecureCacheStorage

Decorator that adds encryption and compression to any storage backend.

### Usage

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),  // or HiveCacheStorage
  encryptor: SimpleEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);

final cache = SmartCacheManager(
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

final cache = SmartCacheManager(
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
  encryptor: SimpleEncryptor('secret_key'),
  compressor: SimpleCompressor(),
);

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### Memory Only (Simple)

For testing or when persistence isn't needed:

```dart
final cache = SmartCacheManager(
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
final cache2 = SmartCacheManager(
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
