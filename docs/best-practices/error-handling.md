# Error Handling

Strategies for handling errors in Smart Cache.

---

## Default Behavior

Smart Cache handles errors gracefully:

```dart
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
);
// If fetcher throws, cache returns null (or last cached value)
// No try-catch needed!
```

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
// SyncEngine retries failed tasks up to 3 times
final syncEngine = SyncEngine(
  executor: (task) async {
    try {
      await api.sendData(task.body);
      return true;
    } catch (e) {
      return false; // Will retry
    }
  },
);
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
  // Falls back to cache automatically with networkFirst
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
    crashReporter.recordError(event.error, event.stackTrace);
    
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
final data = await cache.get<String>(key: 'data');

// Good: always has fallback
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => null, // or api.getData()
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
