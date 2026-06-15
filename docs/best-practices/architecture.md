# Architecture Best Practices

Patterns for structuring your app with Smart Cache.

---

## Singleton Pattern

Use a singleton for app-wide cache access:

```dart
// app_cache.dart
class AppCache {
  static final AppCache _instance = AppCache._();
  factory AppCache() => _instance;
  AppCache._();

  late final SmartCacheManager cache;
  late final SyncEngine syncEngine;

  Future<void> init() async {
    final hiveStorage = HiveCacheStorage(boxName: 'app_cache');
    await hiveStorage.init();

    cache = SmartCacheManager(
      memoryStorage: MemoryCacheStorage(),
      persistentStorage: hiveStorage,
      mode: kReleaseMode ? SmartCacheMode.production : SmartCacheMode.dev,
    );

    syncEngine = SyncEngine(
      executor: _executeTask,
      queueBoxName: 'sync_queue',
    );
    await syncEngine.init();

    cache.syncEngine = syncEngine;
  }

  Future<bool> _executeTask(SyncTask task) async {
    // Your sync logic here
    return true;
  }

  void dispose() {
    cache.dispose();
    syncEngine.dispose();
  }
}
```

### Usage

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppCache().init();
  runApp(MyApp());
}

// Anywhere in your app
final cache = AppCache().cache;
```

---

## Dependency Injection

Use a service locator or DI framework:

```dart
// Using GetIt
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerLazySingleton(() => SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: HiveCacheStorage(boxName: 'cache'),
  ));

  getIt.registerLazySingleton(() => ApiService(
    cache: getIt<SmartCacheManager>(),
  ));
}

// Usage
final api = getIt<ApiService>();
```

---

## Service Layer

Create a cache service for each domain:

```dart
class UserService {
  final SmartCacheManager _cache;
  final ApiClient _api;

  UserService(this._cache, this._api);

  Future<User> getProfile(String userId) async {
    return _cache.get<User>(
      key: 'profile_$userId',
      fetcher: () => _api.getProfile(userId),
      ttl: const Duration(hours: 1),
    );
  }

  Future<List<User>> getUsers() async {
    return _cache.get<List<User>>(
      key: 'users',
      fetcher: () => _api.getUsers(),
      ttl: const Duration(minutes: 30),
      policy: CachePolicy.cacheFirst,
    );
  }

  Future<void> updateProfile(User user) async {
    await _api.updateProfile(user);
    await _cache.set<User>(
      key: 'profile_${user.id}',
      data: user,
    );
  }
}
```

---

## File Structure

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── cache_config.dart
│   └── api_config.dart
├── services/
│   ├── cache_service.dart
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── user_service.dart
├── models/
│   ├── user.dart
│   └── post.dart
├── screens/
│   ├── home_screen.dart
│   └── profile_screen.dart
└── widgets/
    └── cached_avatar.dart
```

---

## Best Practices

### 1. Initialize Early

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize cache before app starts
  await AppCache().init();
  
  runApp(MyApp());
}
```

### 2. Use Named Keys

```dart
// Bad
await cache.set(key: 'a', data: '1');

// Good
await cache.set(key: 'user_profile_123', data: user);
```

### 3. Set Appropriate TTLs

```dart
// Short TTL for frequently changing data
await cache.get(key: 'feed', ttl: const Duration(minutes: 5));

// Long TTL for rarely changing data
await cache.get(key: 'settings', ttl: const Duration(hours: 24));

// No TTL for persistent data
await cache.get(key: 'user_data', ttl: null);
```

### 4. Handle Errors Gracefully

```dart
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => api.getData(),
);
// Data is always returned (from cache, network, or null)
// No try-catch needed!
```

### 5. Clean Up on Logout

```dart
Future<void> logout() async {
  await cache.invalidateByContext(
    CacheContext(userId: currentUser.id),
  );
  cache.clearContext();
}
```

---

## Next

- [Error Handling](error-handling.md)
- [Testing](testing.md)
- [Performance](performance.md)
