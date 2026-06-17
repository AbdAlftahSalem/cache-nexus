# Request Deduplication

Smart Cache automatically deduplicates concurrent requests for the same key.

---

## How It Works

When multiple widgets or components request the same cache key simultaneously, Smart Cache makes only **one network call** and shares the result.

```dart
// These 3 calls happen at the same time
// Only ONE API call is made
final future1 = cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
);
final future2 = cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
);
final future3 = cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
);

final results = await Future.wait([future1, future2, future3]);
// All 3 return the same data
// Only 1 API call was made
```

---

## Example: Multiple Widgets

```dart
// Widget A
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserList(users: users),
);

// Widget B (also requests 'users')
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserCount(count: users?.length ?? 0),
);

// Widget C (also requests 'users')
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserAvatar(user: users?.first),
);

// When 'users' is fetched, only ONE API call is made
// All 3 widgets receive the same data
```

---

## Example: Timer-based Refresh

```dart
// Refresh every 30 seconds
Timer.periodic(const Duration(seconds: 30), (_) async {
  final users = await cache.get<List<User>>(
    key: 'users',
    fetcher: () => api.getUsers(),
    policy: CachePolicy.networkFirst,
  );
  // Multiple timer ticks deduplicate if still in-flight
});
```

---

## Example: User Actions

```dart
// User taps refresh button rapidly
onPressed: () async {
  final data = await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData(),
    policy: CachePolicy.networkFirst,
  );
},

// Even if tapped 5 times quickly, only 1 API call is made
```

---

## Deduplication Window

Deduplication is automatic and happens within the same event loop tick. If requests are spaced apart, they may trigger separate fetches.

```dart
// These may NOT deduplicate (different ticks)
await cache.get(key: 'a', fetcher: () => fetch());
await Future.delayed(const Duration(seconds: 1));
await cache.get(key: 'a', fetcher: () => fetch());

// These WILL deduplicate (same tick)
final f1 = cache.get(key: 'a', fetcher: () => fetch());
final f2 = cache.get(key: 'a', fetcher: () => fetch());
await Future.wait([f1, f2]);
```

---

## Next Snippets

- [Cache Invalidation](cache_invalidation.md)
- [Stream Debounce](stream_debounce.md)
- [Basic CRUD](basic_crud.md)
