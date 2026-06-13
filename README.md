<p align="center">
  <h1 align="center">Smart Cache</h1>
  <p align="center">Offline-first, debuggable data orchestration layer for Flutter</p>
</p>

<p align="center">
  <a href="https://pub.dev/packages/smart_cache"><img src="https://img.shields.io/pub/v/smart_cache.svg" alt="pub.dev"></a>
  <a href="https://github.com/AbdAlftahSalem/smart-cache/blob/main/LICENSE"><img src="https://img.shields.io/github/license/AbdAlftahSalem/smart-cache" alt="license"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue.svg" alt="flutter"></a>
  <a href="https://github.com/AbdAlftahSalem/smart-cache"><img src="https://img.shields.io/github/stars/AbdAlftahSalem/smart-cache?style=social" alt="stars"></a>
</p>

---

Smart Cache is **not just a caching library**. It is a full **data orchestration layer** between UI, API, and local storage. It handles caching, offline fallback, request deduplication, security, reactive streams, and built-in developer debugging tools -- so you don't have to.

---

## Features

- **TTL-based caching** with automatic expiration
- **5 cache policies**: cacheFirst, networkFirst, cacheOnly, networkOnly, staleWhileRevalidate
- **Two-tier storage**: fast in-memory + persistent Hive storage
- **Request deduplication**: concurrent requests for the same key share one network call
- **Offline support**: automatic fallback to persistent cache when offline
- **Offline sync queue**: enqueue tasks that retry when connectivity returns
- **Security layer**: encryption + compression decorators for cached data
- **Auth-aware caching**: isolate cache by user ID and role
- **Reactive streams**: `watch()` API with `SmartCacheBuilder` widget for auto UI rebuilds
- **Built-in dev tools**: floating debug button, live event panel, stats dashboard
- **Production safe**: all dev features tree-shaken in release builds, zero overhead
- **Cache stats**: hit/miss/fetch/error tracking with hit rate

---

## Getting Started

### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  smart_cache:
    path: ../smart_cache  # or from pub.dev when published
```

```bash
flutter pub get
```

### 2. Initialize the cache

```dart
import 'package:smart_cache/smart_cache.dart';

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
);
```

### 3. Start caching

```dart
final users = await cache.get<List<String>>(
  key: 'users',
  fetcher: () async {
    final response = await http.get(Uri.parse('https://api.example.com/users'));
    return jsonDecode(response.body);
  },
  ttl: Duration(hours: 1),
);

print(users); // ['Alice', 'Bob', 'Charlie']
```

That's it. On the next call with the same key, data is returned instantly from memory (cache hit) without any network request.

---

## Installation

### From pub.dev (when published)

```yaml
dependencies:
  smart_cache: ^1.0.0
```

### From local path

```yaml
dependencies:
  smart_cache:
    path: ../smart_cache
```

### From Git

```yaml
dependencies:
  smart_cache:
    git:
      url: https://github.com/AbdAlftahSalem/smart-cache.git
      ref: main
```

Then run:

```bash
flutter pub get
```

---

## Core Concepts

### SmartCacheManager

The central class that orchestrates all caching operations:

```dart
final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),       // fast, volatile
  persistentStorage: hiveStorage,             // durable (optional)
  mode: SmartCacheMode.dev,                   // dev or production
);
```

### CacheEntry

Every cached item is wrapped in a `CacheEntry`:

```dart
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration? ttl;

  bool get isExpired; // true if createdAt + ttl < now
}
```

### CacheStorage

Abstract interface for storage backends:

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

## Cache Policies

Smart Cache supports 5 cache strategies:

```dart
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: Duration(minutes: 30),
  policy: CachePolicy.cacheFirst, // choose your strategy
);
```

### cacheFirst (default)

Check cache first. If hit, return. If miss or expired, fetch from network.

```dart
// Best for: data that doesn't change often (user profile, settings)
final profile = await cache.get<User>(
  key: 'profile',
  fetcher: () => api.getProfile(),
  ttl: Duration(hours: 1),
  policy: CachePolicy.cacheFirst,
);
```

### networkFirst

Try network first. If it fails (e.g., offline), fall back to cache.

```dart
// Best for: real-time data that should be fresh (feed, notifications)
final feed = await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  ttl: Duration(minutes: 5),
  policy: CachePolicy.networkFirst,
);
```

### cacheOnly

Never hit the network. Return cached data or throw if missing.

```dart
// Best for: offline-only data, local drafts
final drafts = await cache.get<List<Draft>>(
  key: 'drafts',
  fetcher: () => throw Exception('Should not fetch'),
  policy: CachePolicy.cacheOnly,
);
```

### networkOnly

Always fetch from network. Cache is ignored completely.

```dart
// Best for: critical real-time data (payment status, OTP)
final status = await cache.get<PaymentStatus>(
  key: 'payment_123',
  fetcher: () => api.checkPayment('123'),
  policy: CachePolicy.networkOnly,
);
```

### staleWhileRevalidate

Return cached data instantly, then refresh in the background.

```dart
// Best for: show stale data immediately, update silently
final products = await cache.get<List<Product>>(
  key: 'products',
  fetcher: () => api.getProducts(),
  ttl: Duration(minutes: 10),
  policy: CachePolicy.staleWhileRevalidate,
);
```

### Policy Summary

| Policy | Cache | Network | Fallback on Error | Use Case |
|---|---|---|---|---|
| `cacheFirst` | Check first | On miss | -- | Static data |
| `networkFirst` | Fallback | Try first | Return cache | Real-time with offline |
| `cacheOnly` | Read only | Never | -- | Offline data |
| `networkOnly` | Ignored | Always | -- | Critical real-time |
| `staleWhileRevalidate` | Return instantly | Background | -- | Instant UI |

---

## Two-Tier Storage

Smart Cache uses a **memory-first** architecture with optional persistent storage:

```dart
final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),    // Layer 1: fast, volatile
  persistentStorage: hiveStorage,         // Layer 2: durable, survives restart
);
```

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
import 'package:smart_cache/smart_cache.dart';

final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
await hiveStorage.init(); // initialize Hive

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
);
```

### How the Two Tiers Work

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

## Security Layer

`SecureCacheStorage` wraps any `CacheStorage` and applies **compress-then-encrypt** on write, **decrypt-then-decompress** on read.

### Basic Usage

```dart
import 'package:smart_cache/smart_cache.dart';

final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),                    // or HiveCacheStorage
  encryptor: SimpleEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);

final cache = SmartCacheManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### Custom Encryptor

Implement the `CacheEncryptor` interface for your own encryption:

```dart
class AesEncryptor implements CacheEncryptor {
  final String key;

  AesEncryptor(this.key);

  @override
  String encrypt(String data) {
    // Use your AES implementation here
    return aesEncrypt(data, key);
  }

  @override
  String decrypt(String data) {
    return aesDecrypt(data, key);
  }
}

final secureStorage = SecureCacheStorage(
  HiveCacheStorage(),
  encryptor: AesEncryptor('your_256_bit_key'),
);
```

### Custom Compressor

Implement the `CacheCompressor` interface for your own compression:

```dart
class GzipCompressor implements CacheCompressor {
  @override
  String compress(String data) {
    // Use gzip/archive library
    return gzip.encode(utf8.encode(data)).toString();
  }

  @override
  String decompress(String data) {
    return utf8.decode(gzip.decode(utf8.encode(data)));
  }
}
```

---

## Auth-Aware Caching

Cache keys are automatically **isolated by user ID and role**. Different users never see each other's cached data.

### Set User Context

```dart
cache.setContext(CacheContext(
  userId: 'user_123',
  role: 'admin',
));
```

Now all cache keys are automatically prefixed:

```
user_123_admin_users
user_123_admin_profile
```

### Switch Users

```dart
// User A
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
final adminData = await cache.get<String>(key: 'secret', fetcher: () => 'Admin Only');

// User B (isolated -- different cache keys)
cache.setContext(CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(key: 'secret', fetcher: () => 'Public Only');
// adminData and guestData are completely separate
```

### Smart Invalidation

Invalidate cache for a specific user without affecting others:

```dart
// Invalidate only User A's cache
await cache.invalidateByContext(CacheContext(userId: 'user_123'));

// Invalidate all admin users
await cache.invalidateByContext(CacheContext(role: 'admin'));
```

### Clear Context

```dart
cache.clearContext(); // back to global (unprefixed) keys
```

---

## Reactive Streams

Smart Cache supports **reactive programming** -- watch cache keys and get notified when data changes.

### watch() API

```dart
// Watch a cache key for changes
cache.watch<List<User>>('users').listen((users) {
  if (users != null) {
    print('Users updated: ${users.length}');
  } else {
    print('Users deleted or not found');
  }
});

// Update the cache -- all watchers are notified automatically
await cache.set(key: 'users', data: [User('Alice'), User('Bob')]);
```

### watch() with Debounce

Prevent rapid UI rebuilds during fast updates:

```dart
cache.watch<List<Product>>(
  'products',
  debounce: Duration(milliseconds: 300),
).listen((products) {
  setState(() => _products = products);
});
```

### SmartCacheBuilder Widget

A Flutter widget that **automatically rebuilds** when a cache key changes:

```dart
SmartCacheBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) {
    if (users == null) {
      return const CircularProgressIndicator();
    }
    return ListView(
      children: users.map((u) => Text(u.name)).toList(),
    );
  },
);
```

### SmartCacheBuilder with Debounce

```dart
SmartCacheBuilder<List<Message>>(
  cache: cache,
  cacheKey: 'messages',
  debounce: Duration(milliseconds: 500),
  builder: (context, messages) {
    if (messages == null) return const SizedBox();
    return MessageList(messages: messages);
  },
);
```

### How It Works

1. `watch(key)` subscribes to a broadcast `StreamController` for that key
2. On subscription, the current value (if any) is emitted immediately
3. When `set()` or `delete()` is called, all subscribers for that key are notified
4. `SmartCacheBuilder` listens to this stream and calls `setState()` on updates

---

## Offline Sync

The `SyncEngine` manages a persistent queue of tasks that retry automatically when connectivity returns.

### Setup

```dart
import 'package:smart_cache/smart_cache.dart';

final syncEngine = SyncEngine(
  executor: (task) async {
    // Execute the sync task (e.g., send to server)
    try {
      await http.post(
        Uri.parse(task.endpoint),
        body: jsonEncode(task.body),
      );
      return true; // success
    } catch (e) {
      return false; // will retry
    }
  },
  queueBoxName: 'offline_queue',
);

await syncEngine.init();
```

### Enqueue Tasks

```dart
await cache.enqueueSyncTask(SyncTask(
  id: 'order_001',
  key: 'order_001',
  endpoint: 'https://api.example.com/orders',
  method: 'POST',
  body: {'item': 'widget', 'quantity': 2},
  createdAt: DateTime.now(),
));
```

### How It Works

1. Task is persisted to Hive (survives app restart)
2. If online, task is processed immediately
3. If offline, task stays in queue
4. When connectivity returns, all queued tasks are processed in order
5. Failed tasks retry up to **3 times**, then are dropped

---

## Dev Mode

Smart Cache includes built-in **developer tools** that are automatically disabled in production.

### Enable Dev Mode

```dart
final cache = SmartCacheManager(
  mode: SmartCacheMode.dev,        // enables all dev features
  // mode: SmartCacheMode.production, // disables everything (default)
);
```

### Debug Overlay

Add the floating debug button to your app:

```dart
MaterialApp(
  builder: (context, child) {
    return SmartCacheOverlay(
      manager: cache,
      child: child!,
    );
  },
);
```

A floating blue button appears in the bottom-right corner. Tap it to open the **Dev Panel** showing:

- **Live event list**: every cache hit, miss, fetch, error in real-time
- **Stats dashboard**: hit count, miss count, fetch count, error count, hit rate
- **Request detail viewer**: tap any event to see full request/response data

### Event System

Listen to cache events programmatically:

```dart
cache.events.listen((event) {
  print('[${event.type.name}] ${event.key} - ${event.duration?.inMilliseconds ?? 0}ms');
});

// Event types: hit, miss, fetch, store, error, expired, evict
```

### Cache Stats

Access real-time statistics:

```dart
print('Hits: ${cache.stats.hits}');
print('Misses: ${cache.stats.misses}');
print('Fetches: ${cache.stats.fetches}');
print('Errors: ${cache.stats.errors}');
print('Hit Rate: ${(cache.stats.hitRate * 100).toStringAsFixed(1)}%');
```

### Production Safety

In `SmartCacheMode.production`:

- `_emit()` returns immediately (no events created)
- Stats are not tracked
- Overlay widget renders just the child (no FAB)
- **Zero performance overhead** in release builds

```dart
final cache = SmartCacheManager(
  mode: kReleaseMode ? SmartCacheMode.production : SmartCacheMode.dev,
);
```

---

## Architecture

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

## API Reference

### SmartCacheManager

| Method | Description |
|---|---|
| `get<T>(key, fetcher, {ttl, policy})` | Get data with cache policy and optional fetcher |
| `set<T>(key, data, {ttl})` | Store data in cache |
| `delete(key)` | Remove a key from cache |
| `clear()` | Remove all cached data |
| `watch<T>(key, {debounce})` | Watch a key for changes (returns `Stream<T?>`) |
| `setContext(context)` | Set auth-aware cache context |
| `clearContext()` | Remove current context |
| `invalidateByContext(context)` | Invalidate all keys matching a context prefix |
| `enqueueSyncTask(task)` | Add a task to the offline sync queue |
| `dispose()` | Clean up streams and subscriptions |

### SmartCacheManager Properties

| Property | Type | Description |
|---|---|---|
| `events` | `Stream<CacheEvent>` | Stream of cache events (dev mode) |
| `stats` | `CacheStats` | Current cache statistics |
| `context` | `CacheContext?` | Current auth context |

### SmartCacheManager Constructor

```dart
SmartCacheManager({
  CacheStorage? memoryStorage,        // default: MemoryCacheStorage()
  CacheStorage? persistentStorage,    // default: null (no persistence)
  SyncEngine? syncEngine,             // default: null (no sync)
  SmartCacheMode mode,                // default: SmartCacheMode.production
  CacheContext? context,              // default: null
})
```

### CacheEntry

| Property | Type | Description |
|---|---|---|
| `data` | `T` | The cached data |
| `createdAt` | `DateTime` | When the entry was created |
| `ttl` | `Duration?` | Time-to-live (null = never expires) |
| `isExpired` | `bool` | Whether the entry has expired |

### CacheStorage Implementations

| Class | Description |
|---|---|
| `MemoryCacheStorage` | In-memory Map-based storage (fast, volatile) |
| `HiveCacheStorage` | Persistent Hive-based storage (survives restart) |
| `SecureCacheStorage` | Decorator: adds encryption + compression to any storage |

### SecureCacheStorage Constructor

```dart
SecureCacheStorage(
  CacheStorage inner, {
  CacheEncryptor? encryptor,    // default: NoOpEncryptor
  CacheCompressor? compressor,  // default: NoOpCompressor
})
```

### CachePolicy

| Value | Behavior |
|---|---|
| `cacheFirst` | Cache first, fetch on miss |
| `networkFirst` | Network first, cache on failure |
| `cacheOnly` | Cache only, no network |
| `networkOnly` | Network only, ignore cache |
| `staleWhileRevalidate` | Return stale, refresh in background |

### CacheContext

```dart
CacheContext({
  required String userId,
  String? token,
  String? role,
})
```

| Property | Type | Description |
|---|---|---|
| `userId` | `String` | User identifier (required) |
| `token` | `String?` | Auth token (optional) |
| `role` | `String?` | User role for isolation (optional) |
| `cacheKeyPrefix` | `String` | Auto-generated prefix: `userId_role_` |

### CacheEvent

| Property | Type | Description |
|---|---|---|
| `key` | `String` | Cache key involved |
| `type` | `CacheEventType` | Event type (hit/miss/fetch/store/error/expired/evict) |
| `timestamp` | `DateTime` | When the event occurred |
| `data` | `dynamic` | Associated data (for hit/fetch/store) |
| `duration` | `Duration?` | Request duration (for fetch/error) |
| `error` | `Object?` | Error object (for error events) |

### CacheStats

| Property | Type | Description |
|---|---|---|
| `hits` | `int` | Number of cache hits |
| `misses` | `int` | Number of cache misses |
| `fetches` | `int` | Number of network fetches |
| `errors` | `int` | Number of errors |
| `hitRate` | `double` | Hit rate as a fraction (0.0 - 1.0) |

### SyncTask

```dart
SyncTask({
  required String id,
  required String key,
  required String endpoint,
  required String method,
  dynamic body,
  required DateTime createdAt,
  int retryCount = 0,    // auto-incremented, max 3
})
```

### SyncEngine Constructor

```dart
SyncEngine({
  required SyncTaskExecutor executor,   // function to execute tasks
  String queueBoxName,                  // default: 'sync_queue'
})
```

### NetworkStatus

| Method | Description |
|---|---|
| `NetworkStatus.isOnline` | `Future<bool>` -- check connectivity |
| `NetworkStatus.onConnectivityChanged` | `Stream<bool>` -- listen for changes |
| `NetworkStatus.setMockStatus(bool?)` | Set mock status for testing |

### SmartCacheBuilder

```dart
SmartCacheBuilder<T>({
  required SmartCacheManager cache,
  required String cacheKey,
  required Widget Function(BuildContext, T?) builder,
  Duration? debounce,
})
```

---

## Project Structure

```text
smart_cache/
├── lib/
│   ├── smart_cache.dart                    # Public API barrel export
│   └── src/
│       ├── cache_manager.dart              # SmartCacheManager (core)
│       ├── cache_entry.dart                # CacheEntry<T> model
│       ├── cache_storage.dart              # CacheStorage interface
│       ├── memory_cache_storage.dart       # In-memory Map storage
│       ├── hive_cache_storage.dart         # Hive persistent storage
│       ├── secure_cache_storage.dart       # Encryption + compression
│       ├── cache_encryptor.dart            # CacheEncryptor interface
│       ├── cache_compressor.dart           # CacheCompressor interface
│       ├── cache_policy.dart               # CachePolicy enum (5 strategies)
│       ├── cache_event.dart                # CacheEvent + CacheEventType
│       ├── cache_stats.dart                # CacheStats (hits/misses)
│       ├── cache_context.dart              # Auth-aware key prefix
│       ├── sync_task.dart                  # SyncTask model
│       ├── sync_metadata.dart              # SyncMetadata model
│       ├── sync_engine.dart                # Offline sync queue
│       ├── network_status.dart             # Connectivity detection
│       ├── subscription_manager.dart       # Stream lifecycle manager
│       ├── smart_cache_builder.dart        # Reactive Flutter widget
│       ├── observable_cache_entry.dart     # Reactive cache entry
│       ├── reactive_cache_store.dart       # Reactive storage wrapper
│       └── dev/
│           ├── smart_cache_overlay.dart    # Floating debug FAB
│           ├── cache_panel_screen.dart     # Live event panel
│           ├── cache_detail_screen.dart    # Request detail viewer
│           ├── cache_stats_widget.dart     # Stats dashboard widget
│           └── cache_timeline_widget.dart  # Event timeline widget
├── example/
│   └── smart_cache_example.dart            # Usage examples
├── test/
│   ├── smart_cache_test.dart               # Core: policies, dedup, SWR
│   ├── observability_test.dart             # Dev mode event/stats tests
│   ├── offline_engine_test.dart            # Hive, persistence, sync queue
│   ├── reactive_test.dart                  # Watch API, debounce, leaks
│   └── security_test.dart                 # Encryption, auth isolation
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
└── README.md
```

---

## Testing

### Run All Tests

```bash
flutter test
```

### Run a Specific Test File

```bash
flutter test test/smart_cache_test.dart
flutter test test/security_test.dart
flutter test test/reactive_test.dart
flutter test test/observability_test.dart
flutter test test/offline_engine_test.dart
```

### What's Tested

| Test File | Tests | Coverage |
|---|---|---|
| `smart_cache_test.dart` | 14 tests | TTL, get/set/delete, all 5 policies, dedup, SWR |
| `observability_test.dart` | 4 tests | Event emission, stats, production mode safety |
| `offline_engine_test.dart` | 7 tests | Hive persistence, expiration, corruption, sync queue |
| `reactive_test.dart` | 9 tests | watch API, debounce, multiple listeners, memory leaks |
| `security_test.dart` | 5 tests | Encryption roundtrip, auth isolation, smart invalidation |

### Run Analysis

```bash
dart analyze
```

---

## Roadmap

### Completed

- [x] Phase 1: Memory Cache, TTL System, Basic Fetch Flow
- [x] Phase 2: Cache Policies, Expiration Control, Stats System
- [x] Phase 3: Request Deduplication, Stale While Revalidate
- [x] Phase 4: Hive Persistent Storage, Two-Tier Architecture
- [x] Phase 5: Encryption, Compression, Auth-Aware Caching
- [x] Phase 6: Reactive Streams, SmartCacheBuilder Widget
- [x] Phase 7: Offline Sync Queue, Background Retry

### Planned

- [ ] Phase 8: Full Dev Dashboard, Request Timeline, Analytics, Export Logs (JSON/CSV)
- [ ] Phase 9: Dio/Retrofit Integration, Tag-Based Invalidation
- [ ] Phase 10: Cache Warming, Prefetching, Background Refresh Scheduling
- [ ] pub.dev publication

---

## Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone
git clone https://github.com/AbdAlftahSalem/smart-cache.git
cd smart-cache

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run analysis
dart analyze
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with ❤️ for Flutter developers who care about performance, simplicity, and debugging clarity.
</p>
