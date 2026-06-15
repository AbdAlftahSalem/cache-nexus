## 1.1.0

- **Refactor:** Decomposed `SmartCacheManager` god object into 3 focused classes
  - `ObservabilityManager` — events, stats, network recording
  - `PolicyResolver` — 5 cache strategies with deduplication
  - `ReactiveEngine` — unified watch() API with auto-cleanup
- **Fix:** Memory leak — `StreamController`s now auto-close when last listener drops
- **Fix:** Type safety — `TypeAdapter<T>` system replaces silent `_tryCast`
- **Fix:** Deprecated `Color.withOpacity` → `Color.withValues` across examples
- **Fix:** Broken imports and API mismatches in `docs/examples/`
- **Fix:** Debug `print()` statements removed from `ObservabilityManager`
- **Tests:** 64 tests across 5 files (up from 39)
- **DevOps:** Added GitHub Actions CI (analyze + test), MIT license
- **Zero breaking changes** — public API surface is identical

## 1.0.0

- Initial release of Smart Cache
- Two-tier storage: in-memory (MemoryCacheStorage) + persistent (HiveCacheStorage)
- 5 cache policies: cacheFirst, networkFirst, cacheOnly, networkOnly, staleWhileRevalidate
- TTL-based automatic cache expiration
- Request deduplication for concurrent identical requests
- Security layer: SecureCacheStorage with encryption + compression decorators
- Auth-aware caching: CacheContext for user/role-based cache isolation
- Reactive streams: watch() API with SmartCacheBuilder widget
- Offline sync queue: SyncEngine with automatic retry on connectivity
- Built-in dev tools: floating overlay, live event panel, stats dashboard
- NetworkStatus connectivity detection via connectivity_plus
- Production-safe mode: all dev features tree-shaken in release builds
- Comprehensive test suite: 39 tests across 5 test files
