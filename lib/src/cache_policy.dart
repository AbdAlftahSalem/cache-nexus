enum CachePolicy {
  /// Try cache, if exists and not expired -> return, else -> fetch API
  cacheFirst,

  /// Call API, if success -> store + return, if fail -> fallback to cache
  networkFirst,

  /// Return cache only (no network call)
  cacheOnly,

  /// Always fetch API, ignore cache completely
  networkOnly,

  /// Return cache instantly (even if expired?), then refresh API in background
  /// Note: If cache doesn't exist, it behaves like cacheFirst (fetches and returns)
  staleWhileRevalidate,
}
