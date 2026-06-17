# Security & Auth

Smart Cache provides encryption for sensitive data and auth-aware caching to isolate cache by user ID and role.

---

## Security Layer

`SecureCacheStorage` wraps any `CacheStorage` and applies **compress-then-encrypt** on write, **decrypt-then-decompress** on read.

### Basic Usage

```dart
import 'package:cache_nexus/cache_nexus.dart';

final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),                    // or HiveCacheStorage
  encryptor: SimpleEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);
```

### How It Works

```
Write: data → compress → encrypt → storage
Read:  storage → decrypt → decompress → data
```

---

## Custom Encryptor

Implement the `CacheEncryptor` interface for your own encryption:

```dart
class AesEncryptor implements CacheEncryptor {
  final String key;

  AesEncryptor(this.key);

  @override
  String encrypt(String data) {
    // Use your AES implementation here
    return aesEncrypt(data, key);
  }

  @override
  String decrypt(String data) {
    return aesDecrypt(data, key);
  }
}

final secureStorage = SecureCacheStorage(
  HiveCacheStorage(),
  encryptor: AesEncryptor('your_256_bit_key'),
);
```

### Interface

```dart
abstract class CacheEncryptor {
  String encrypt(String data);
  String decrypt(String data);
}
```

---

## Custom Compressor

Implement the `CacheCompressor` interface for your own compression:

```dart
class GzipCompressor implements CacheCompressor {
  @override
  String compress(String data) {
    // Use gzip/archive library
    return gzip.encode(utf8.encode(data)).toString();
  }

  @override
  String decompress(String data) {
    return utf8.decode(gzip.decode(utf8.encode(data)));
  }
}
```

### Interface

```dart
abstract class CacheCompressor {
  String compress(String data);
  String decompress(String data);
}
```

---

## Auth-Aware Caching

Cache keys are automatically **isolated by user ID and role**. Different users never see each other's cached data.

### Set User Context

```dart
cache.setContext(CacheContext(
  userId: 'user_123',
  role: 'admin',
));
```

Now all cache keys are automatically prefixed:

```
user_123_admin_users
user_123_admin_profile
```

### Switch Users

```dart
// User A
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
final adminData = await cache.get<String>(
  key: 'secret',
  fetcher: () => 'Admin Only',
);

// User B (isolated -- different cache keys)
cache.setContext(CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(
  key: 'secret',
  fetcher: () => 'Public Only',
);

// adminData and guestData are completely separate
```

### Smart Invalidation

Invalidate cache for a specific user without affecting others:

```dart
// Invalidate only User A's cache
await cache.invalidateByContext(CacheContext(userId: 'user_123'));

// Invalidate all users (CacheContext requires userId, so use clear for global)
await cache.clear();
```

### Clear Context

```dart
cache.clearContext(); // back to global (unprefixed) keys
```

---

## CacheContext Properties

```dart
CacheContext({
  required String userId,
  String? token,
  String? role,
})
```

| Property | Type | Description |
|----------|------|-------------|
| `userId` | `String` | User identifier (required) |
| `token` | `String?` | Auth token (optional) |
| `role` | `String?` | User role for isolation (optional) |
| `cacheKeyPrefix` | `String` | Auto-generated prefix: `userId_role_` |

---

## Example: Multi-User App

```dart
// Login as Admin
await authService.login('admin@example.com', 'password');
cache.setContext(CacheContext(
  userId: authService.currentUser.id,
  role: 'admin',
));

// Fetch admin data
final adminDashboard = await cache.get<Dashboard>(
  key: 'dashboard',
  fetcher: () => api.getAdminDashboard(),
  ttl: Duration(minutes: 5),
);

// Logout
cache.clearContext();
await authService.logout();

// Login as Guest
cache.setContext(CacheContext(
  userId: 'guest_123',
  role: 'guest',
));

// Guest sees different data (different cache keys)
final guestDashboard = await cache.get<Dashboard>(
  key: 'dashboard',
  fetcher: () => api.getGuestDashboard(),
  ttl: Duration(minutes: 5),
);
```

---

## Best Practices

### Use Strong Keys

```dart
// Bad: weak key
final cache = SecureCacheStorage(
  storage,
  encryptor: SimpleEncryptor('123'),
);

// Good: strong key
final cache = SecureCacheStorage(
  storage,
  encryptor: SimpleEncryptor('your_256_bit_key_here'),
);
```

### Store Keys Securely

```dart
// Bad: hardcoded key
final encryptor = SimpleEncryptor('secret_key');

// Good: from secure storage
final key = await SecureStorage.read('encryption_key');
final encryptor = SimpleEncryptor(key);
```

### Use Unique User IDs

```dart
// Bad: generic user ID
cache.setContext(CacheContext(userId: 'user'));

// Good: specific user ID
cache.setContext(CacheContext(userId: 'user_1234567890'));
```

---

## Next Steps

- [Reactive Streams](reactive-streams.md) - Watch API and widgets
- [Offline Sync](offline-sync.md) - SyncEngine for offline-first apps
- [Dev Tools](dev-tools.md) - Debug overlay and event monitoring
