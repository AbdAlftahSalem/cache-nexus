# Cache Invalidation

Strategies for invalidating cached data.

---

## Manual Invalidation

```dart
// Delete a specific key
await cache.delete( 'users');

// Delete multiple keys
await cache.delete( 'users');
await cache.delete( 'posts');
await cache.delete( 'comments');

// Clear everything
await cache.clear();
```

---

## Invalidation by Prefix

```dart
// Delete all keys starting with 'user_'
// Note: deleteByPrefix is on CacheStorage, not SmartCacheManager directly
await cache.memoryStorage.deleteByPrefix('user_');

// Examples:
// user_123_profile → deleted
// user_123_settings → deleted
// user_456_profile → NOT deleted
```

---

## Context-Based Invalidation

```dart
// Invalidate cache for a specific user
await cache.invalidateByContext(
  CacheContext(userId: 'user_123'),
);

// Invalidate cache for a specific user with role context
await cache.invalidateByContext(
  CacheContext(userId: 'user_123', role: 'admin'),
);

// Invalidate all users
await cache.clear();
```

---

## TTL-Based Invalidation

```dart
// Data expires after TTL
await cache.set<String>(
  key: 'token',
  data: 'abc123',
  ttl: const Duration(hours: 24), // Expires after 24 hours
);

// After 24 hours, next get() returns null (cache miss)
final token = await cache.get<String>(
  key: 'token',
  fetcher: () => null,
);
// token == null after expiration
```

---

## Policy-Based Invalidation

```dart
// Always fetch fresh (ignore cache)
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
  policy: CachePolicy.networkOnly,
);

// Return stale, refresh in background
final products = await cache.get<List<Product>>(
  key: 'products',
  fetcher: () => api.getProducts(),
  policy: CachePolicy.staleWhileRevalidate,
);
```

---

## Event-Based Invalidation

```dart
// Listen to events and invalidate accordingly
cache.events.listen((event) {
  if (event.type == CacheEventType.error) {
    // Clear cache on error
    cache.clear();
  }
});
```

---

## Example: Logout

```dart
Future<void> logout() async {
  // 1. Invalidate user-specific cache
  await cache.invalidateByContext(
    CacheContext(userId: currentUser.id),
  );

  // 2. Clear auth token
  await cache.delete( 'auth_token');

  // 3. Clear context
  cache.clearContext();
}
```

---

## Example: Data Refresh

```dart
Future<void> refreshData() async {
  // Delete stale data
  await cache.delete( 'users');
  await cache.delete( 'posts');

  // Fetch fresh data
  await cache.get<List<User>>(
    key: 'users',
    fetcher: () => api.getUsers(),
    policy: CachePolicy.networkFirst,
  );
}
```

---

## Next Snippets

- [Stream Debounce](stream_debounce.md)
- [Basic CRUD](basic_crud.md)
- [Custom Encryptor](custom_encryptor.md)
