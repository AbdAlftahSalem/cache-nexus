# Auth Flow Example

A complete authentication flow demonstrating Smart Cache's auth-aware caching, user context switching, and cache isolation.

## Features Demonstrated

- **Auth-Aware Caching**: Cache keys isolated by user ID and role
- **Context Switching**: Switch between users without data leakage
- **Smart Invalidation**: Invalidate cache for specific users
- **Secure Storage**: Encrypted cache for sensitive data
- **Reactive UI**: Auto-updating UI with watch()

## Flow

1. **Login**: Set user context with userId and role
2. **Profile**: Fetch user-specific data (different cache keys per user)
3. **Switch User**: Clear context, set new user (isolated cache)
4. **Logout**: Clear context, invalidate user cache

## Code Snippets

### Initialize Cache

```dart
final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: SecureCacheStorage(
    MemoryCacheStorage(),
    encryptor: SimpleEncryptor('auth_secret_key'),
    compressor: SimpleCompressor(),
  ),
  mode: CacheNexusMode.dev,
);
```

### Login Flow

```dart
class AuthService {
  final CacheNexusManager _cache;

  AuthService(this._cache);

  Future<User> login(String email, String password) async {
    // 1. Authenticate with API
    final response = await api.login(email, password);
    final user = User.fromJson(response.data);

    // 2. Set cache context (isolates all subsequent cache calls)
    _cache.setContext(CacheContext(
      userId: user.id,
      role: user.role,
    ));

    // 3. Cache user data with context
    await _cache.set<User>(
      key: 'profile',
      data: user,
      ttl: Duration(hours: 1),
    );

    return user;
  }

  Future<void> logout() async {
    // 1. Invalidate user-specific cache
    await _cache.invalidateByContext(
      CacheContext(userId: currentUser.id),
    );

    // 2. Clear context (back to global keys)
    _cache.clearContext();
  }
}
```

### User Profile Screen

```dart
class ProfileScreen extends StatelessWidget {
  final CacheNexusManager cache;

  const ProfileScreen({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return CacheNexusBuilder<User>(
      cache: cache,
      cacheKey: 'profile',
      builder: (context, user) {
        if (user == null) {
          return CircularProgressIndicator();
        }
        return Column(
          children: [
            CircleAvatar(child: Text(user.name[0])),
            Text(user.name),
            Text(user.email),
            Text('Role: ${user.role}'),
          ],
        );
      },
    );
  }
}
```

### Switch User

```dart
// User A logs in
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
final adminData = await cache.get<String>(key: 'secret', fetcher: () => 'Admin Data');

// User B logs in (isolated - different cache keys)
cache.setContext(CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(key: 'secret', fetcher: () => 'Guest Data');

// adminData != guestData (completely separate)
```

### Invalidate Specific User

```dart
// Invalidate only User A's cache (User B unaffected)
await cache.invalidateByContext(CacheContext(userId: 'user_123'));

// Invalidate a specific user with role context
await cache.invalidateByContext(CacheContext(userId: 'user_123', role: 'admin'));
```

## Security Features

### Encrypted Storage

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),
  encryptor: SimpleEncryptor('your_secret_key'),
  compressor: SimpleCompressor(),
);
```

### Token Caching

```dart
// Cache auth token (encrypted)
await _cache.set<String>(
  key: 'auth_token',
  data: response.token,
  ttl: Duration(hours: 24),
);

// Retrieve token
final token = await _cache.get<String>(
  key: 'auth_token',
  fetcher: () => null,
);
```

## Running

```bash
flutter run
```

## Dependencies

- `cache_nexus`: Cache with auth isolation
- `dio`: HTTP client
- `hive_flutter`: Persistent storage
