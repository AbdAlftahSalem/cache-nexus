<p align="center">
  <h1 align="center">Cache-nexus</h1>
  <p align="center">Offline-first, debuggable data orchestration layer for Flutter</p>
</p>

<p align="center">
  <a href="https://pub.dev/packages/cache_nexus"><img src="https://img.shields.io/pub/v/cache_nexus.svg" alt="pub.dev"></a>
  <a href="https://github.com/AbdAlftahSalem/cache-nexus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/AbdAlftahSalem/cache-nexus" alt="license"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue.svg" alt="flutter"></a>
  <a href="https://github.com/AbdAlftahSalem/cache-nexus"><img src="https://img.shields.io/github/stars/AbdAlftahSalem/cache-nexus?style=social" alt="stars"></a>
</p>

---

Smart Cache is **not just a caching library**. It is a full **data orchestration layer** between UI, API, and local storage. It handles caching, offline fallback, request deduplication, security, reactive streams, and built-in developer debugging tools -- so you don't have to.

---

## Quick Start (5 minutes)

### 1. Add dependency

```yaml
# pubspec.yaml
dependencies:
  cache_nexus: ^1.0.0
```

### 2. Initialize & cache

```dart
import 'package:cache_nexus/cache_nexus.dart';

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
);

final users = await cache.get<List<String>>(
  key: 'users',
  fetcher: () async => ['Alice', 'Bob', 'Charlie'],
  ttl: Duration(hours: 1),
);

print(users); // ['Alice', 'Bob', 'Charlie']
// Next call with same key returns instantly from cache!
```

That's it. See [docs/getting-started/quick-start.md](docs/getting-started/quick-start.md) for the full runnable example.

---

## Features

| Feature | Description |
|---------|-------------|
| **5 Cache Policies** | cacheFirst, networkFirst, cacheOnly, networkOnly, staleWhileRevalidate |
| **Two-Tier Storage** | Fast in-memory + persistent Hive |
| **Request Deduplication** | Concurrent requests share one network call |
| **Offline Support** | Automatic fallback to persistent cache |
| **Offline Sync Queue** | Tasks retry when connectivity returns |
| **Security Layer** | Encryption + compression decorators |
| **Auth-Aware Caching** | Isolate cache by user ID and role |
| **Reactive Streams** | `watch()` API + `CacheNexusBuilder` widget |
| **Dev Tools** | Floating debug button, live event panel, stats |
| **Cache Stats** | Hit/miss/fetch/error tracking with hit rate |

---

## Documentation

| Section | Description |
|---------|-------------|
| **[Getting Started](docs/getting-started/)** | Installation, quick-start, hello-world |
| **[Guides](docs/guides/)** | Core concepts, policies, storage, security, reactive, offline, dev tools |
| **[Examples](docs/examples/)** | Real-world examples with code snippets |
| **[Best Practices](docs/best-practices/)** | Architecture, testing, performance, migration |
| **[API Reference](docs/api/)** | Complete class/method documentation |
| **[FAQ](docs/faq/)** | Common issues and troubleshooting |

---

## Examples

### Blog App

A complete blog app with posts list, detail view, cache policies, reactive UI, and offline sync.

**Features demonstrated:**
- CacheNexusBuilder for auto-rebuilding UI
- Cache policies (cacheFirst vs networkFirst)
- Request deduplication
- Dev tools overlay

See [docs/examples/blog-app/](docs/examples/blog-app/) for full code.

### Auth Flow

Login, user context switching, cache isolation between users, and secure logout.

**Features demonstrated:**
- Auth-aware caching
- CacheContext for user isolation
- Smart invalidation by context
- Encrypted storage for sensitive data

See [docs/examples/auth-flow/](docs/examples/auth-flow/) for full code.

### Offline Todo

Create, edit, and delete todos offline with automatic sync when online.

**Features demonstrated:**
- SyncEngine for offline queue
- Auto-retry on connectivity return
- Persistent cache across app restarts
- NetworkStatus monitoring

See [docs/examples/offline-todo/](docs/examples/offline-todo/) for full code.

---

## Code Snippets

| Snippet | Description |
|---------|-------------|
| **[Basic CRUD](docs/examples/snippets/basic_crud.md)** | Create, read, update, delete cache entries |
| **[Custom Encryptor](docs/examples/snippets/custom_encryptor.md)** | Implement your own encryption |
| **[Cache Warming](docs/examples/snippets/cache_warming.md)** | Pre-populate cache on startup |
| **[Testing Patterns](docs/examples/snippets/testing_patterns.md)** | Unit and widget testing |
| **[Request Dedup](docs/examples/snippets/request_deduplication.md)** | Concurrent request handling |
| **[Cache Invalidation](docs/examples/snippets/cache_invalidation.md)** | Invalidation strategies |
| **[Stream Debounce](docs/examples/snippets/stream_debounce.md)** | Prevent rapid UI rebuilds |

---

## Installation

### From pub.dev (when published)

```yaml
dependencies:
  cache_nexus: ^1.0.0
```

### From Git

```yaml
dependencies:
  cache_nexus:
    git:
      url: https://github.com/AbdAlftahSalem/cache-nexus.git
      ref: main
```

### From local path

```yaml
dependencies:
  cache_nexus:
    path: ../cache_nexus
```

Then run:

```bash
flutter pub get
```

---

## Best Practices

### Singleton Pattern

```dart
// app_cache.dart
class AppCache {
  static final AppCache _instance = AppCache._();
  factory AppCache() => _instance;
  AppCache._();

  final CacheNexusManager cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: HiveCacheStorage(boxName: 'app_cache'),
    mode: kReleaseMode ? CacheNexusMode.production : CacheNexusMode.dev,
  );
}
```

### Error Handling

```dart
final data = await cache.get<User>(
  key: 'profile',
  fetcher: () => api.getProfile(),
  ttl: Duration(minutes: 15),
);
// Data is always returned (from cache, network, or null)
// No try-catch needed!
```

### Migration

Already using Hive, shared_preferences, or Riverpod? See [docs/best-practices/migration.md](docs/best-practices/migration.md) for side-by-side comparisons.

---

## Roadmap

### Completed

- [x] Phase 1: Memory Cache, TTL System, Basic Fetch Flow
- [x] Phase 2: Cache Policies, Expiration Control, Stats System
- [x] Phase 3: Request Deduplication, Stale While Revalidate
- [x] Phase 4: Hive Persistent Storage, Two-Tier Architecture
- [x] Phase 5: Encryption, Compression, Auth-Aware Caching
- [x] Phase 6: Reactive Streams, CacheNexusBuilder Widget
- [x] Phase 7: Offline Sync Queue, Background Retry

### Planned
- [ ] Phase 8: Dio/Retrofit Integration, Tag-Based Invalidation
- [ ] Phase 9: Cache Warming, Prefetching, Background Refresh Scheduling
- [ ] Phase 10: Full Dev Dashboard, Request Timeline, Analytics, Export Logs (JSON/CSV)
- pub.dev publication

---

## Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup.

---

## Contact

| Platform | Link |
|----------|------|
| **WhatsApp** | [+972 59 804 5064](https://wa.me/972598045064) |
| **Email** | [abdalftah.ps@gmail.com](mailto:abdalftah.ps@gmail.com) |
| **LinkedIn** | [Abd Alftah Salem](https://www.linkedin.com/in/abd-alftah-salem-a3ba0b1bb/) |

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with ❤️ for Flutter developers who care about performance, simplicity, and debugging clarity.
</p>
