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
- Comprehensive test suite: 83 tests across 5 test files
