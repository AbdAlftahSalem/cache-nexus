## 1.1.0

No breaking API changes. Every 1.0 API keeps working; deprecated names are listed below.

### Fixed

- **Offline data survives app restarts.** Values read back from Hive (`List<dynamic>`, `Map<dynamic, dynamic>`) were treated as cache misses, so the fetcher ran again and could overwrite saved offline data. Maps are now normalised and common collections (`List<String>`, `List<int>`, `Map<String, dynamic>`, ...) decode automatically.
- Registered adapters are no longer called on memory hits (a second `get` crashed), are used when writing (`toData` was never called) and errors inside them no longer escape.
- `staleWhileRevalidate` now serves expired entries immediately and refreshes in the background, as documented.
- `networkFirst` rethrows the original network error when nothing is cached (instead of a generic "Cache missing" exception).
- A cached `null` (`get<T?>`) is a hit and is not fetched again on every call.
- A failed cache write no longer turns a successful fetch into an error.
- Keys longer than 255 UTF-8 bytes (long URLs, long Arabic keys) no longer throw in Hive; they are hashed transparently and prefix deletes still find them.
- `CacheContext` prefixes are unambiguous (`ali` + role `admin` no longer collides with user `ali_admin`). Entries written by 1.0 are migrated on first read.
- `watch()` emits once per change (was twice), a new watcher no longer re-sends the current value to existing watchers, and `clear()` / `invalidateByContext()` notify watchers with `null`.
- Errors in watch streams (unreadable values) are delivered as stream errors instead of crashing.
- `SyncEngine`: an executor that throws (e.g. `DioException`) counts as a failed attempt instead of jamming the queue and escaping `enqueue()`; tasks added during a pass are sent in that pass; unreadable rows are skipped.
- `SimpleEncryptor` corrupted any non-Latin-1 text (Arabic included); it now round-trips all Unicode and still reads 1.0 values.
- `SimpleCompressor` made data bigger (it only added a marker); it now compresses with GZip and still reads 1.0 values.
- `CacheNexusOverlay` crashed inside `MaterialApp.builder` (no `Navigator`) and wrapped the app in an extra `Scaffold`.
- Using the manager after `dispose()` (e.g. a fetch finishing after a screen closed) no longer throws; `dispose()` is idempotent and also disposes the `SyncEngine`.
- `NetworkStatus.dispose()` no longer closes the shared stream forever; connectivity errors in plain Dart tests are ignored.
- Dev stats count HTTP status ≥ 400 as failed; `trackNetworkRequest` reports the real status code.

### Added

- `CacheAdapter<T>` and `CacheAdapter.json(fromJson:, toJson:)`. One registration covers `T`, `T?`, `List<T>` and `Map<String, T>`.
- `CacheDecodeException` (with a hint on which adapter to register) and `CacheMissException`.
- `AesGcmEncryptor`: AES-GCM with app-supplied key, random nonce per value, authentication; `generateKey()` and `fromBase64()`.
- `GZipCompressor` (pure Dart, works on web).
- `SyncEngine`: `maxRetries`, `retryDelay` (exponential backoff, auto-scheduled), `maxRetryDelay`, `failedTasks`, `retryFailed()`, `onTaskFailed`, `isInitialized`; `SyncTask.lastError` and `nextAttemptAt`. Bodies with `toJson()` are converted when enqueued.
- `CacheNexusBuilder`: `loadingBuilder`, `errorBuilder`, `onError`.
- `CacheNexusOverlay(navigatorKey:)`; the panel has a close button.
- `CacheNexusDioInterceptor` redacts `Authorization`, cookies and API-key headers (`redactedHeaders:` to customise).
- `CacheContext.userKeyPrefix`, `legacyCacheKeyPrefix`, value equality; `CacheEntry.expiresAt`; `HiveCacheStorage.close()` / `isInitialized`; `CacheNexusManager.isDisposed`; `trackNetworkRequest(statusCodeOf:)`.
- API documentation for the public API.

### Changed

- Storage uses **Hive CE** (`hive_ce`, `hive_ce_flutter`) instead of the unmaintained `hive` 2.2.3. Hive CE reads boxes written by Hive 2.x, so existing caches and queued tasks are kept. Apps that initialise Hive themselves should import `hive_ce` / `hive_ce_flutter`.
- `invalidateByContext` with a role removes only that role's data; without a role it removes all of the user's data (as before).
- Expired entries are no longer deleted on read (so `staleWhileRevalidate` can serve them); they are replaced on the next store.
- The package is WebAssembly-compatible.
- Minimum versions stated correctly: Dart 3.11, Flutter 3.41.

### Deprecated

- `TypeAdapter` → use `CacheAdapter` (the old name clashes with Hive's `TypeAdapter`).
- `SimpleEncryptor` → it is XOR obfuscation, not encryption; use `AesGcmEncryptor`.

## 1.0.0

- Initial release.
- Two-tier storage: in-memory (`MemoryCacheStorage`) + persistent (`HiveCacheStorage`).
- 5 cache policies: cacheFirst, networkFirst, cacheOnly, networkOnly, staleWhileRevalidate.
- TTL-based expiration and request deduplication.
- `SecureCacheStorage` with encryptor/compressor decorators.
- `CacheContext` for user/role-based isolation.
- `watch()` and `CacheNexusBuilder`.
- `SyncEngine` offline queue.
- Dev tools: floating overlay, event panel, stats (runtime `CacheNexusMode`).
- 86 tests across 6 files.
