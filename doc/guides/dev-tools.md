# Dev Tools

Cache Nexus includes built-in **developer tools** that are automatically disabled in production.

---

## Enable Dev Mode

```dart
final cache = CacheNexusManager(
  mode: CacheNexusMode.dev,        // enables all dev features
  // mode: CacheNexusMode.production, // disables everything (default)
);
```

---

## Debug Overlay

Add the floating debug button to your app:

```dart
MaterialApp(
  builder: (context, child) {
    return CacheNexusOverlay(
      manager: cache,
      child: child!,
    );
  },
);
```

This works inside `MaterialApp.builder`, where there is no `Navigator` above the overlay: the panel then opens on top of your app with its own navigator and a close button. You can also wrap a single page (the panel is pushed on the app's navigator), or pass `navigatorKey:` to push it on a specific navigator. The overlay adds no `Scaffold` of its own.

A floating blue button appears in the bottom-right corner. Tap it to open the **Dev Panel** showing:

- **Live event list**: every cache hit, miss, fetch, error in real-time
- **Stats dashboard**: hit count, miss count, fetch count, error count, hit rate
- **Request detail viewer**: tap any event to see full request/response data

### Capturing Dio traffic

```dart
final dio = Dio()..interceptors.add(CacheNexusDioInterceptor(cache));
```

Requests, responses (status ≥ 400 counts as failed) and errors appear in the panel's NETWORK tab. `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie` and `X-Api-Key` header values are recorded as `<redacted>`; pass `redactedHeaders:` to change the list.

---

## Event System

Listen to cache events programmatically:

```dart
cache.events.listen((event) {
  print('[${event.type.name}] ${event.key} - ${event.duration?.inMilliseconds ?? 0}ms');
});

// Event types: hit, miss, fetch, store, error, expired, evict
```

### Event Types

| Type | Description |
|------|-------------|
| `hit` | Cache hit (data returned from cache) |
| `miss` | Cache miss (data not found) |
| `fetch` | Network fetch started |
| `store` | Data stored in cache |
| `error` | Error occurred |
| `expired` | Entry expired |
| `evict` | Entry evicted |

### Event Properties

```dart
class CacheEvent {
  final String key;
  final CacheEventType type;
  final DateTime timestamp;
  final dynamic data;
  final Duration? duration;
  final Object? error;
}
```

---

## Cache Stats

Access real-time statistics:

```dart
print('Hits: ${cache.stats.hits}');
print('Misses: ${cache.stats.misses}');
print('Fetches: ${cache.stats.fetches}');
print('Errors: ${cache.stats.errors}');
print('Hit Rate: ${(cache.stats.hitRate * 100).toStringAsFixed(1)}%');
```

### Stats Properties

| Property | Type | Description |
|----------|------|-------------|
| `hits` | `int` | Number of cache hits |
| `misses` | `int` | Number of cache misses |
| `fetches` | `int` | Number of network fetches |
| `errors` | `int` | Number of errors |
| `hitRate` | `double` | Hit rate as a fraction (0.0 - 1.0) |

---

## Production Safety

In `CacheNexusMode.production` (the default):

- No events are created and stats are not tracked
- `CacheNexusOverlay` renders just the child (no button)
- `CacheNexusDioInterceptor` passes requests through untouched

The mode is a runtime switch: the dev-tool widgets are still compiled into your app, they just do nothing. Choose the mode from `kReleaseMode` so release builds never record traffic:

```dart
final cache = CacheNexusManager(
  mode: kReleaseMode ? CacheNexusMode.production : CacheNexusMode.dev,
);
```

---

## Example: Debug Logging

```dart
void main() {
  final cache = CacheNexusManager(
    mode: CacheNexusMode.dev,
  );

  // Log all events
  cache.events.listen((event) {
    switch (event.type) {
      case CacheEventType.hit:
        print('✅ CACHE HIT: ${event.key}');
        break;
      case CacheEventType.miss:
        print('❌ CACHE MISS: ${event.key}');
        break;
      case CacheEventType.fetch:
        print('🌐 FETCHING: ${event.key} (${event.duration?.inMilliseconds ?? 0}ms)');
        break;
      case CacheEventType.error:
        print('⚠️ ERROR: ${event.key} - ${event.error}');
        break;
      default:
        print('📌 ${event.type.name}: ${event.key}');
    }
  });

  // Use cache normally
  final data = await cache.get<String>(
    key: 'test',
    fetcher: () async => 'Hello!',
  );
}
```

---

## Example: Stats Dashboard

```dart
class StatsDashboard extends StatelessWidget {
  final CacheNexusManager cache;

  const StatsDashboard({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CacheEvent>(
      stream: cache.events,
      builder: (context, snapshot) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cache Stats', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Hits: ${cache.stats.hits}'),
                Text('Misses: ${cache.stats.misses}'),
                Text('Fetches: ${cache.stats.fetches}'),
                Text('Errors: ${cache.stats.errors}'),
                Text('Hit Rate: ${(cache.stats.hitRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## Best Practices

### Use Dev Mode in Development

```dart
final cache = CacheNexusManager(
  mode: kReleaseMode ? CacheNexusMode.production : CacheNexusMode.dev,
);
```

### Monitor Performance

```dart
cache.events.listen((event) {
  if (event.type == CacheEventType.fetch) {
    final duration = event.duration?.inMilliseconds ?? 0;
    if (duration > 1000) {
      print('⚠️ Slow fetch: ${event.key} took ${duration}ms');
    }
  }
});
```

### Track Hit Rate

```dart
// Log hit rate periodically
Timer.periodic(Duration(minutes: 5), (_) {
  print('Hit Rate: ${(cache.stats.hitRate * 100).toStringAsFixed(1)}%');
});
```

---

## Next Steps

- [Blog App Example](../examples/blog-app/) - Complete dev tools example
- [Testing](../best-practices/testing.md) - How to test cache behavior
- [Performance](../best-practices/performance.md) - Optimize cache usage
