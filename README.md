<p align="center">
  <h1 align="center">Cache Nexus</h1>
  <p align="center">Offline-first, debuggable caching and data orchestration for Flutter</p>
</p>

<p align="center">
  <a href="https://pub.dev/packages/cache_nexus"><img src="https://img.shields.io/pub/v/cache_nexus.svg" alt="pub.dev"></a>
  <a href="https://github.com/AbdAlftahSalem/cache-nexus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/AbdAlftahSalem/cache-nexus" alt="license"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.41-blue.svg" alt="Flutter >= 3.41"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-%3E%3D3.11-blue.svg" alt="Dart >= 3.11"></a>
  <a href="https://github.com/AbdAlftahSalem/cache-nexus"><img src="https://img.shields.io/github/stars/AbdAlftahSalem/cache-nexus?style=social" alt="stars"></a>
</p>

---

Cache Nexus sits between your UI, your API and local storage. It caches in memory and on disk (Hive CE), applies one of five cache policies per call, keeps typed data across app restarts, encrypts what you ask it to, isolates data per user, pushes changes to widgets, queues offline writes, and shows everything in a dev panel.

---

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  cache_nexus: ^1.1.0
```

### 2. Create the cache once

```dart
import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter/foundation.dart';

late final CacheNexusManager cache;

Future<void> setupCache() async {
  final disk = HiveCacheStorage(boxName: 'app_cache');
  await disk.init();

  cache = CacheNexusManager(
    persistentStorage: disk,
    mode: kReleaseMode ? CacheNexusMode.production : CacheNexusMode.dev,
  );

  // Teach the cache how to rebuild your classes after a restart.
  cache.registerAdapter<Post>(
    CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
  );
}
```

### 3. Read through the cache

```dart
final posts = await cache.get<List<Post>>(
  key: 'posts',
  fetcher: () => api.getPosts(),
  ttl: const Duration(minutes: 10),
  policy: CachePolicy.staleWhileRevalidate,
);
```

The first call fetches and stores; later calls (also after an app restart, also offline) are served from the cache. See [doc/getting-started/quick-start.md](doc/getting-started/quick-start.md) for a full runnable app.

---

## Features

| Feature | Description |
|---------|-------------|
| **5 cache policies** | `cacheFirst`, `networkFirst`, `cacheOnly`, `networkOnly`, `staleWhileRevalidate` ([exact semantics](doc/guides/cache-policies.md)) |
| **Two-tier storage** | In-memory + persistent Hive CE; long and non-Latin keys handled |
| **Typed data across restarts** | Built-in decoding for common collections; `CacheAdapter` for your classes (covers `List<T>` and `Map<String, T>` too) |
| **Request deduplication** | Concurrent calls for the same key share one fetch |
| **Offline support** | Cached data is served when the network is down |
| **Offline sync queue** | `SyncEngine` with retries, exponential backoff and a failed-task list |
| **Encryption** | `AesGcmEncryptor` (AES-GCM, authenticated) + `GZipCompressor` via `SecureCacheStorage` |
| **Per-user isolation** | `CacheContext` scopes keys by user and role; invalidate on logout |
| **Reactive UI** | `watch()` streams and `CacheNexusBuilder` with loading/error builders |
| **Dev tools** | Floating overlay, live event panel, Dio interceptor, hit/miss stats |

---

## Highlights

### Policies

```dart
// Fresh when possible, cached when offline, real error when neither works
final feed = await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  policy: CachePolicy.networkFirst,
);
```

`staleWhileRevalidate` returns the cached value immediately, even past its TTL, and refreshes in the background; watchers get the fresh value when it lands. `networkFirst` falls back to a fresh cached value and otherwise rethrows the original network error (for example the `DioException`).

### Encryption

```dart
final secure = SecureCacheStorage(
  disk,
  encryptor: AesGcmEncryptor.fromBase64(keyFromSecureStorage),
  compressor: const GZipCompressor(),
);
```

Generate the key once with `AesGcmEncryptor.generateKey()` and keep it in the platform keystore (e.g. `flutter_secure_storage`). `SimpleEncryptor` is XOR obfuscation, not encryption, and is deprecated. See [Security & Auth](doc/guides/security-auth.md).

### Per-user data

```dart
cache.setContext(CacheContext(userId: user.id));
// ... on logout:
await cache.invalidateByContext(CacheContext(userId: user.id));
cache.clearContext();
```

### Reactive widgets

```dart
CacheNexusBuilder<List<Post>>(
  cache: cache,
  cacheKey: 'posts',
  loadingBuilder: (_) => const CircularProgressIndicator(),
  errorBuilder: (_, error, __) => Text('$error'),
  builder: (_, posts) => PostList(posts: posts ?? const []),
);
```

### Offline writes

```dart
final sync = SyncEngine(
  executor: (task) async {
    await dio.request<void>(task.endpoint,
        data: task.body, options: Options(method: task.method));
    return true; // throwing or returning false = retry later
  },
  maxRetries: 5,
  retryDelay: const Duration(seconds: 2), // 2s, 4s, 8s, ...
);
await sync.init();
sync.onTaskFailed.listen((task) => showRetryBanner(task));
```

### Dev tools

```dart
MaterialApp(
  builder: (context, child) => CacheNexusOverlay(manager: cache, child: child!),
  home: const HomeScreen(),
);
dio.interceptors.add(CacheNexusDioInterceptor(cache)); // redacts auth headers
```

---

## Documentation

| Section | Description |
|---------|-------------|
| **[Getting Started](doc/getting-started/)** | Installation, quick start, hello world |
| **[Guides](doc/guides/)** | [Core concepts](doc/guides/core-concepts.md), [policies](doc/guides/cache-policies.md), [storage & typed data](doc/guides/two-tier-storage.md), [security](doc/guides/security-auth.md), [reactive](doc/guides/reactive-streams.md), [offline sync](doc/guides/offline-sync.md), [dev tools](doc/guides/dev-tools.md) |
| **[Examples](doc/examples/)** | Blog app, auth flow, offline todo, snippets |
| **[Best Practices](doc/best-practices/)** | Architecture, testing, performance, error handling, [migration](doc/best-practices/migration.md) |
| **[API Reference](doc/api/)** | Class and method reference |
| **[FAQ](doc/faq/)** | Common issues and troubleshooting |

---

## Examples

- **[example/](example/)**: the showcase app (policies, security, reactive UI, sync queue, dev tools).
- **[Blog App](doc/examples/blog-app/)**: posts list and detail with Dio, policies, reactive UI and offline sync.
- **[Auth Flow](doc/examples/auth-flow/)**: login, per-user isolation, encrypted storage, logout invalidation.
- **[Offline Todo](doc/examples/offline-todo/)**: offline CRUD that survives restarts and syncs when back online.

### Snippets

| Snippet | Description |
|---------|-------------|
| **[Basic CRUD](doc/examples/snippets/basic_crud.md)** | Create, read, update, delete cache entries |
| **[Custom Encryptor](doc/examples/snippets/custom_encryptor.md)** | Plug in your own cipher |
| **[Cache Warming](doc/examples/snippets/cache_warming.md)** | Pre-populate the cache on startup |
| **[Testing Patterns](doc/examples/snippets/testing_patterns.md)** | Unit and widget testing |
| **[Request Dedup](doc/examples/snippets/request_deduplication.md)** | Concurrent request handling |
| **[Cache Invalidation](doc/examples/snippets/cache_invalidation.md)** | Invalidation strategies |
| **[Stream Debounce](doc/examples/snippets/stream_debounce.md)** | Prevent rapid UI rebuilds |

---

## Installation

### From pub.dev

```yaml
dependencies:
  cache_nexus: ^1.1.0
```

### From Git

```yaml
dependencies:
  cache_nexus:
    git:
      url: https://github.com/AbdAlftahSalem/cache-nexus.git
      ref: main
```

Then run `flutter pub get`.

Upgrading from 1.0? There are no breaking API changes; read the [1.0 → 1.1 notes](doc/best-practices/migration.md#from-cache_nexus-10-to-11) (storage moved to Hive CE, which reads your existing boxes).

---

## Error Handling

`get()` answers from the cache whenever the policy allows. When it cannot, the fetcher's error reaches you, so wrap network-backed calls:

```dart
try {
  final profile = await cache.get<User>(
    key: 'profile',
    fetcher: () => api.getProfile(),
    policy: CachePolicy.networkFirst,
  );
} on DioException catch (e) {
  // Network failed and nothing fresh was cached.
}
```

---

## Roadmap

### Done

- Memory cache, TTL, fetch flow, 5 policies, stats
- Request deduplication, stale-while-revalidate
- Hive persistence, two-tier architecture, typed adapters
- AES-GCM encryption, GZip compression, per-user isolation
- Reactive streams and `CacheNexusBuilder`
- Offline sync queue with retries, backoff and failed-task handling
- Dio interceptor and dev panel

### Planned

- Tag-based invalidation
- Cache warming / prefetch helpers, scheduled background refresh
- Dev panel export (JSON/CSV)

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and the checks to run before opening a pull request.

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
