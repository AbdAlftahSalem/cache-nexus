# Cache Warming

Pre-populate cache on app startup for instant data access.

---

## Basic Warming

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: HiveCacheStorage(boxName: 'cache'),
  );

  // Warm cache before running app
  await _warmCache(cache);

  runApp(MyApp(cache: cache));
}

Future<void> _warmCache(SmartCacheManager cache) async {
  // Pre-fetch critical data
  await cache.get<User>(
    key: 'profile',
    fetcher: () => api.getProfile(),
    ttl: const Duration(hours: 1),
  );

  await cache.get<List<Post>>(
    key: 'feed',
    fetcher: () => api.getFeed(),
    ttl: const Duration(minutes: 5),
  );
}
```

---

## Parallel Warming

```dart
Future<void> _warmCache(SmartCacheManager cache) async {
  // Fetch all critical data in parallel
  await Future.wait([
    cache.get<User>(
      key: 'profile',
      fetcher: () => api.getProfile(),
    ),
    cache.get<List<Post>>(
      key: 'feed',
      fetcher: () => api.getFeed(),
    ),
    cache.get<List<Category>>(
      key: 'categories',
      fetcher: () => api.getCategories(),
    ),
  ]);
}
```

---

## Background Warming

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );

  // Start app immediately
  runApp(MyApp(cache: cache));

  // Warm cache in background (non-blocking)
  _warmCacheInBackground(cache);
}

Future<void> _warmCacheInBackground(SmartCacheManager cache) async {
  try {
    await cache.get<List<Post>>(
      key: 'feed',
      fetcher: () => api.getFeed(),
    );
  } catch (e) {
    // Ignore errors during background warming
    print('Background warming failed: $e');
  }
}
```

---

## Conditional Warming

```dart
Future<void> _warmCache(SmartCacheManager cache) async {
  // Only warm if cache is empty
  final existing = await cache.get<String>(key: 'profile', fetcher: () => null);
  if (existing == null) {
    await cache.get<User>(
      key: 'profile',
      fetcher: () => api.getProfile(),
    );
  }

  // Always refresh feed
  await cache.get<List<Post>>(
    key: 'feed',
    fetcher: () => api.getFeed(),
    policy: CachePolicy.networkFirst,
  );
}
```

---

## Warming with Progress

```dart
class WarmingScreen extends StatefulWidget {
  final SmartCacheManager cache;

  const WarmingScreen({super.key, required this.cache});

  @override
  State<WarmingScreen> createState() => _WarmingScreenState();
}

class _WarmingScreenState extends State<WarmingScreen> {
  String _status = 'Warming cache...';
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _warmCache();
  }

  Future<void> _warmCache() async {
    final tasks = [
      ('Profile', () => _warmProfile()),
      ('Feed', () => _warmFeed()),
      ('Settings', () => _warmSettings()),
    ];

    for (int i = 0; i < tasks.length; i++) {
      setState(() {
        _status = 'Loading ${tasks[i].$1}...';
        _progress = i / tasks.length;
      });
      await tasks[i].$2();
    }

    setState(() {
      _status = 'Cache warmed!';
      _progress = 1.0;
    });
  }

  Future<void> _warmProfile() async {
    await widget.cache.get<User>(
      key: 'profile',
      fetcher: () => api.getProfile(),
    );
  }

  Future<void> _warmFeed() async {
    await widget.cache.get<List<Post>>(
      key: 'feed',
      fetcher: () => api.getFeed(),
    );
  }

  Future<void> _warmSettings() async {
    await widget.cache.get<Map<String, dynamic>>(
      key: 'settings',
      fetcher: () => api.getSettings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
```

---

## Next Snippets

- [Testing Patterns](testing_patterns.md)
- [Request Deduplication](request_deduplication.md)
- [Cache Invalidation](cache_invalidation.md)
