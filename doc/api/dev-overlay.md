# Dev Overlay

Debug tools for monitoring cache events and statistics.

---

## CacheNexusOverlay

A floating debug button that opens the Dev Panel.

### Constructor

```dart
CacheNexusOverlay({
  required CacheNexusManager manager,
  required Widget child,
})
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `manager` | `CacheNexusManager` | Cache instance |
| `child` | `Widget` | App widget |

### Usage

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

### What It Shows

A floating blue button appears in the bottom-right corner. Tap it to open the **Dev Panel** showing:

- **Live event list**: every cache hit, miss, fetch, error in real-time
- **Stats dashboard**: hit count, miss count, fetch count, error count, hit rate
- **Request detail viewer**: tap any event to see full request/response data

---

## Event System

Listen to cache events programmatically:

```dart
cache.events.listen((event) {
  print('[${event.type.name}] ${event.key} - ${event.duration?.inMilliseconds ?? 0}ms');
});
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

## Production Mode

In `CacheNexusMode.production`:

- `_emit()` returns immediately (no events created)
- Stats are not tracked
- Overlay widget renders just the child (no FAB)
- **Zero performance overhead** in release builds

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

## Related

- [CacheNexusManager](cache-nexus-manager.md)
- [Dev Tools Guide](../guides/dev-tools.md)
