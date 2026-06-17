# Quick Start

Get Smart Cache up and running in 5 minutes. This guide covers everything from installation to your first cached API call.

---

## Step 1: Add Dependency

```yaml
# pubspec.yaml
dependencies:
  cache_nexus: ^1.0.0
```

Run:
```bash
flutter pub get
```

---

## Step 2: Complete Example

Create a new file `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Cache Demo',
      home: const CacheDemoScreen(),
    );
  }
}

class CacheDemoScreen extends StatefulWidget {
  const CacheDemoScreen({super.key});

  @override
  State<CacheDemoScreen> createState() => _CacheDemoScreenState();
}

class _CacheDemoScreenState extends State<CacheDemoScreen> {
  late final CacheNexusManager _cache;
  List<String>? _users;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Initialize cache with memory storage
    _cache = CacheNexusManager(
      memoryStorage: MemoryCacheStorage(),
    );
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);

    // This is the magic! First call fetches from API,
    // second call returns instantly from cache.
    final users = await _cache.get<List<String>>(
      key: 'users',
      fetcher: () async {
        print('Fetching from API...');
        // Simulate API call
        await Future.delayed(const Duration(seconds: 2));
        return ['Alice', 'Bob', 'Charlie', 'Diana'];
      },
      ttl: const Duration(minutes: 5),
    );

    setState(() {
      _users = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Cache Demo')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _users == null
                ? ElevatedButton(
                    onPressed: _loadUsers,
                    child: const Text('Load Users'),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Found ${_users!.length} users:'),
                      const SizedBox(height: 16),
                      ..._users!.map((user) => Text(user)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Load Again (from cache!)'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
```

---

## Step 3: Run It

```bash
flutter run
```

### What happens:

1. **First tap**: Prints "Fetching from API..." and waits 2 seconds
2. **Second tap**: Returns instantly from cache (no API call!)

---

## Step 4: Add Persistent Storage

To cache data across app restarts, add Hive storage:

```dart
import 'package:cache_nexus/cache_nexus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage
  final hiveStorage = HiveCacheStorage(boxName: 'my_cache');
  await hiveStorage.init();

  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: hiveStorage,  // Survives app restart!
  );

  runApp(MyApp(cache: cache));
}
```

---

## Step 5: Enable Dev Tools

Add the debug overlay to see cache events in real-time:

```dart
MaterialApp(
  builder: (context, child) {
    return CacheNexusOverlay(
      manager: cache,
      child: child!,
    );
  },
  home: const HomeScreen(),
);
```

A floating blue button appears. Tap it to see:
- Cache hits and misses
- Network fetches
- Error logs
- Statistics

---

## What You've Learned

| Concept | Description |
|---------|-------------|
| `CacheNexusManager` | Main cache class |
| `MemoryCacheStorage` | In-memory cache |
| `get()` | Fetch with cache policy |
| `ttl` | Time-to-live (expiration) |
| `fetcher` | Function to fetch fresh data |
| `CacheNexusOverlay` | Debug tools |

---

## Next Steps

- [Hello World](hello-world.md) - Minimal first call
- [Cache Policies](../guides/cache-policies.md) - 5 caching strategies
- [Blog App Example](../examples/blog-app/) - Complete real-world example
