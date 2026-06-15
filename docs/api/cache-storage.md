# CacheStorage

Interface and implementations for cache storage backends.

---

## Interface

```dart
abstract class CacheStorage {
  Future<void> write(String key, CacheEntry entry);
  Future<CacheEntry?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteByPrefix(String prefix);
  Future<void> clear();
}
```

---

## MemoryCacheStorage

In-memory `Map`-based storage. Fastest option, lost on app restart.

### Constructor

```dart
MemoryCacheStorage()
```

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
| Speed | Fastest |
| Persistence | Lost on restart |
| Memory | Limited by device RAM |
| Thread Safety | Single-threaded |

---

## HiveCacheStorage

Persistent storage backed by Hive. Survives app restarts.

### Constructor

```dart
HiveCacheStorage({required String boxName})
```

### Methods

| Method | Description |
|--------|-------------|
| `init()` | Initialize Hive (must call before use) |
| `read(key)` | Read from Hive |
| `write(key, entry)` | Write to Hive |
| `delete(key)` | Delete from Hive |
| `deleteByPrefix(prefix)` | Delete by key prefix |
| `clear()` | Clear all entries |

### Usage

```dart
final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
await hiveStorage.init(); // Must initialize before use

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);
```

### Characteristics

| Feature | Value |
|---------|-------|
| Speed | Fast |
| Persistence | Survives restart |
| Memory | Efficient (disk-based) |
| Thread Safety | Yes |

---

## SecureCacheStorage

Decorator that adds encryption and compression to any storage backend.

### Constructor

```dart
SecureCacheStorage(
  CacheStorage inner, {
  CacheEncryptor? encryptor,
  CacheCompressor? compressor,
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `inner` | `CacheStorage` | - | Storage to wrap |
| `encryptor` | `CacheEncryptor?` | `NoOpEncryptor` | Encryption |
| `compressor` | `CacheCompressor?` | `NoOpCompressor` | Compression |

### Usage

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),
  encryptor: SimpleEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### How It Works

```
Write: data → compress → encrypt → storage
Read:  storage → decrypt → decompress → data
```

### Characteristics

| Feature | Value |
|---------|-------|
| Speed | Slower (encryption overhead) |
| Persistence | Depends on inner storage |
| Security | Encrypted |
| Compression | Reduces size |

---

## CacheEntry

Every cached item is wrapped in a `CacheEntry`.

### Constructor

```dart
CacheEntry({
  required T data,
  required DateTime createdAt,
  Duration? ttl,
})
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | The cached data |
| `createdAt` | `DateTime` | When the entry was created |
| `ttl` | `Duration?` | Time-to-live (null = never expires) |
| `isExpired` | `bool` | Whether the entry has expired |

### Example

```dart
final entry = CacheEntry(
  data: 'hello',
  createdAt: DateTime.now(),
  ttl: const Duration(hours: 1),
);

print(entry.data); // 'hello'
print(entry.isExpired); // false
```

---

## Combining Storages

### Memory + Hive (Recommended)

```dart
final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: HiveCacheStorage(boxName: 'cache'),
);
```

### Memory + Secure Hive

```dart
final hiveStorage = HiveCacheStorage(boxName: 'cache');
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

---

## Related

- [SmartCacheManager](smart-cache-manager.md)
- [CachePolicy](cache-policy.md)
- [Security & Auth](../guides/security-auth.md)
