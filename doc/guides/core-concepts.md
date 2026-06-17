# Core Concepts

Smart Cache is built on three core components: SmartCacheManager, CacheEntry, and CacheStorage. Understanding these will help you use Smart Cache effectively.

---

## SmartCacheManager

The central class that orchestrates all caching operations. This is what you'll use most.

### Initialization

```dart
final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),       // fast, volatile
  persistentStorage: hiveStorage,             // durable (optional)
  mode: SmartCacheMode.dev,                   // dev or production
);
```

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `memoryStorage` | `CacheStorage?` | `MemoryCacheStorage()` | In-memory cache |
| `persistentStorage` | `CacheStorage?` | `null` | Persistent storage |
| `syncEngine` | `SyncEngine?` | `null` | Offline sync queue |
| `mode` | `SmartCacheMode` | `SmartCacheMode.production` | Dev or production mode |
| `context` | `CacheContext?` | `null` | Auth context |

### Key Methods

```dart
// Get data (main method)
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: Duration(minutes: 30),
  policy: CachePolicy.cacheFirst,
);

// Set data manually
await cache.set<List<User>>(key: 'users', data: users);

// Delete data
await cache.delete( 'users');

// Clear all data
await cache.clear();

// Watch for changes
cache.watch<List<User>>('users').listen((users) {
  setState(() => _users = users);
});
```

---

## CacheEntry

Every cached item is wrapped in a `CacheEntry`. This metadata tracks when the entry was created and when it expires.

```dart
class CacheEntry<T> {
  final T data;              // The actual cached data
  final DateTime createdAt;  // When it was stored
  final Duration? ttl;       // Time-to-live (null = never expires)

  bool get isExpired;        // true if createdAt + ttl < now
}
```

### Example

```dart
// When you cache data, it's wrapped automatically
await cache.get<String>(
  key: 'token',
  fetcher: () => 'abc123',
  ttl: Duration(hours: 24),  // Expires after 24 hours
);

// Internally, Smart Cache creates:
// CacheEntry(
//   data: 'abc123',
//   createdAt: DateTime.now(),
//   ttl: Duration(hours: 24),
// )
```

### TTL (Time-to-Live)

| TTL Value | Behavior |
|-----------|----------|
| `Duration(minutes: 5)` | Expires after 5 minutes |
| `Duration(hours: 1)` | Expires after 1 hour |
| `Duration(days: 7)` | Expires after 7 days |
| `null` | Never expires |

---

## CacheStorage

The abstract interface for storage backends. Smart Cache provides three implementations.

### Interface

```dart
abstract class CacheStorage {
  Future<void> write(String key, CacheEntry entry);
  Future<CacheEntry?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteByPrefix(String prefix);
  Future<void> clear();
}
```

### Implementations

| Class | Speed | Persistence | Use Case |
|-------|-------|-------------|----------|
| `MemoryCacheStorage` | ⚡ Fastest | ❌ Volatile | Default, fast access |
| `HiveCacheStorage` | 🔵 Fast | ✅ Persistent | Survives restart |
| `SecureCacheStorage` | 🟡 Slower | ✅ + Security | Sensitive data |

### MemoryCacheStorage

In-memory `Map`-based storage. Fastest option, lost on app restart.

```dart
final memoryStorage = MemoryCacheStorage();

final cache = SmartCacheManager(
  memoryStorage: memoryStorage,
);
```

### HiveCacheStorage

Persistent storage backed by [Hive](https://pub.dev/packages/hive). Survives app restarts.

```dart
final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
await hiveStorage.init();

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);
```

### SecureCacheStorage

Decorator that adds encryption and compression to any storage backend.

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),
  encryptor: SimpleEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);
```

---

## How Two-Tier Storage Works

Smart Cache uses a **memory-first** architecture with optional persistent storage:

1. **Read**: Check memory first. If miss, check persistent storage. If found in persistent, restore to memory.
2. **Write**: Write to both memory and persistent storage.
3. **Delete**: Delete from both tiers.

```dart
// Automatic two-tier behavior
await cache.get<String>(
  key: 'user_token',
  fetcher: () => api.login(),
  ttl: Duration(hours: 24),
);
// First call: fetches from API, stores in both memory + Hive
// Second call (same session): returns from memory (instant)
// Third call (new session): returns from Hive (fast), restores to memory
```

---

## Architecture Diagram

```text
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌──────────────────┐    ┌───────────────────────────┐  │
│  │  SmartCacheBuilder│    │  Manual watch()/get/set   │  │
│  └────────┬─────────┘    └─────────────┬─────────────┘  │
│           │                            │                 │
├───────────┼────────────────────────────┼─────────────────┤
│           ▼                            ▼                 │
│  ┌────────────────────────────────────────────────────┐  │
│  │              SmartCacheManager                     │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │  │
│  │  │ Context  │ │  Stats   │ │  Event Stream    │   │  │
│  │  │ (Auth)   │ │ (Metrics)│ │  (Dev Mode)      │   │  │
│  │  └──────────┘ └──────────┘ └──────────────────┘   │  │
│  └──────────┬──────────────────────┬──────────────────┘  │
│             │                      │                     │
├─────────────┼──────────────────────┼─────────────────────┤
│             ▼                      ▼                     │
│  ┌─────────────────┐   ┌──────────────────────────┐     │
│  │ MemoryStorage   │   │  PersistentStorage       │     │
│  │ (Map<String,    │   │  (HiveCacheStorage /     │     │
│  │  CacheEntry>)   │   │   SecureCacheStorage)    │     │
│  └─────────────────┘   └──────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  ┌─────────────────┐   ┌──────────────────────────┐     │
│  │  SyncEngine     │   │  NetworkStatus           │     │
│  │  (Offline Queue)│   │  (connectivity_plus)     │     │
│  └─────────────────┘   └──────────────────────────┘     │
└──────────────────────────────────────────────────────────┘
```

---

## Next Steps

- [Cache Policies](cache-policies.md) - 5 caching strategies
- [Two-Tier Storage](two-tier-storage.md) - Memory + Hive deep dive
- [Security & Auth](security-auth.md) - Encryption and user isolation
