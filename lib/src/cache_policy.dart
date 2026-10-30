/// How `CacheNexusManager.get` combines the cache and the fetcher.
///
/// Every successful fetch is stored and pushed to watchers, whatever the
/// policy. See `doc/guides/cache-policies.md` for the full table.
enum CachePolicy {
  /// Return a fresh cached value; on a miss or an expired entry, fetch.
  cacheFirst,

  /// Fetch first. If the fetch fails, return a fresh cached value; if there is
  /// none, rethrow the original error. When offline, read the cache without
  /// calling the fetcher.
  networkFirst,

  /// Never fetch. Return a fresh cached value, otherwise throw
  /// `CacheMissException` (or return `null` when `T` is nullable).
  cacheOnly,

  /// Always fetch and ignore the cache (the result is still stored).
  networkOnly,

  /// Return any cached value immediately, **even if expired**, and refresh it
  /// in the background when online. Fetch only when nothing is cached.
  staleWhileRevalidate,
}
