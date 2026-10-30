# Error Handling

Strategies for handling errors in Cache Nexus.

---

## Default Behavior

`get()` returns cached data whenever the policy allows it, but **errors from the fetcher do reach you** when the cache cannot answer. Wrap calls that may hit the network:

```dart
try {
  final data = await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData(),
    policy: CachePolicy.networkFirst,
  );
  show(data);
} on DioException catch (e) {
  // Network failed AND nothing fresh was cached: this is the real error,
  // not a generic "cache missing" exception.
  showError(e.message);
}
```

What each policy does on failure:

| Policy | Fetcher throws |
|--------|----------------|
| `cacheFirst` | on a miss, the error is rethrown |
| `networkFirst` | fresh cached value if any, else the original error |
| `cacheOnly` | fetcher never runs; `CacheMissException` (or `null` for nullable `T`) on a miss |
| `networkOnly` | rethrown |
| `staleWhileRevalidate` | cached value (even expired) if any; background errors become error events |

Cache write failures (for example a full disk) never fail a successful fetch; they are reported as error events.

### Decode errors

If a value exists but cannot be converted to the requested type (typically a custom class read back from disk without a registered `CacheAdapter`), it is treated as a miss, a `CacheDecodeException` error event is emitted and a debug log explains which adapter to register. `cacheOnly` throws the `CacheDecodeException`.

---

## Error Events

Listen to error events:

```dart
cache.events.listen((event) {
  if (event.type == CacheEventType.error) {
    print('Error: ${event.key} - ${event.error}');
  }
});
```

---

## Retry Strategies

### Automatic Retry

```dart
// SyncEngine retries failed tasks (maxRetries, default 3) with backoff
final syncEngine = SyncEngine(
  maxRetries: 5,
  retryDelay: const Duration(seconds: 2),
  executor: (task) async {
    try {
      await api.sendData(task.body);
      return true;
    } catch (e) {
      return false; // Will retry (throwing works too)
    }
  },
);
syncEngine.onTaskFailed.listen((task) => report(task.lastError));
```

### Manual Retry

```dart
Future<T?> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(initialDelay * (i + 1));
    }
  }
  return null;
}

// Usage
final data = await retryWithBackoff(() async {
  return await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData(),
  );
});
```

---

## Error Types

```dart
// Network errors
try {
  final data = await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData(),
    policy: CachePolicy.networkFirst,
  );
} on NetworkException catch (e) {
  // Only reached when there is no fresh cached value to fall back to
}

// Timeout errors
try {
  final data = await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData().timeout(Duration(seconds: 5)),
  );
} on TimeoutException catch (e) {
  // Use cached data if available
}

// Auth errors
try {
  final data = await cache.get<String>(
    key: 'data',
    fetcher: () => api.getData(),
  );
} on AuthException catch (e) {
  // Refresh token and retry
  await authService.refreshToken();
  // Retry the request
}
```

---

## Fallback Strategies

### Cache First, Network Fallback

```dart
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
  policy: CachePolicy.cacheFirst,
);
// Returns cached data if available, fetches on miss
```

### Network First, Cache Fallback

```dart
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
  policy: CachePolicy.networkFirst,
);
// Tries network first, falls back to cache on error
```

### Offline-Only

```dart
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => throw Exception('Offline'),
  policy: CachePolicy.cacheOnly,
);
// Only returns cached data, never hits network
```

---

## Error Reporting

```dart
cache.events.listen((event) {
  if (event.type == CacheEventType.error) {
    // Report to crash reporting service
    crashReporter.recordError(event.error, null);
    
    // Log for debugging
    print('Cache error: ${event.key} - ${event.error}');
  }
});
```

---

## Best Practices

### 1. Always Provide Fetcher

```dart
// Bad: no fallback if cache miss
final data = await cache.get<String>(key: 'data', fetcher: () => api.getData());

// Good: always has fallback
final data = await cache.get<String>(
  key: 'data',
  fetcher: () async => null, // or api.getData()
);
```

### 2. Use Appropriate Policy

```dart
// For critical data that must be fresh
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
  policy: CachePolicy.networkOnly,
);

// For data that can be stale
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
  policy: CachePolicy.cacheFirst,
);
```

### 3. Monitor Errors

```dart
cache.events.listen((event) {
  if (event.type == CacheEventType.error) {
    analytics.track('cache_error', {
      'key': event.key,
      'error': event.error.toString(),
    });
  }
});
```

---

## Next

- [Testing](testing.md)
- [Performance](performance.md)
- [Migration](migration.md)
