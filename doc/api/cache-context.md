# CacheContext

Auth-aware cache key isolation.

---

## Constructor

```dart
CacheContext({
  required String userId,
  String? token,
  String? role,
})
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userId` | `String` | Yes | User identifier |
| `token` | `String?` | No | Auth token |
| `role` | `String?` | No | User role for isolation |

---

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `userId` | `String` | User identifier |
| `token` | `String?` | Auth token |
| `role` | `String?` | User role |
| `userKeyPrefix` | `String` | `u<len>:<userId>\|` (all of the user's data) |
| `cacheKeyPrefix` | `String` | `userKeyPrefix` + `r\|` (no role) or `r<len>:<role>\|` |
| `legacyCacheKeyPrefix` | `String` | The 1.0 prefix `userId_role_`, used to migrate old entries |

---

## Usage

### Set Context

```dart
cache.setContext(CacheContext(
  userId: 'user_123',
  role: 'admin',
));
```

All subsequent cache calls are automatically prefixed:

```
u8:user_123|r5:admin|users
u8:user_123|r5:admin|profile
```

The lengths make the prefix unambiguous: user `ali` with role `admin` and user `ali_admin` can never share keys. Entries written by 1.0 under `user_123_admin_` are migrated on first read.

### Switch Users

```dart
// User A
cache.setContext(CacheContext(userId: 'user_123', role: 'admin'));
final adminData = await cache.get<String>(
  key: 'secret',
  fetcher: () async => 'Admin Only',
);

// User B (isolated)
cache.setContext(CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(
  key: 'secret',
  fetcher: () async => 'Public Only',
);

// adminData and guestData are completely separate
```

### Clear Context

```dart
cache.clearContext(); // back to global (unprefixed) keys
```

---

## Smart Invalidation

Invalidate cache for a specific user without affecting others:

```dart
// All of User A's data (every role)
await cache.invalidateByContext(const CacheContext(userId: 'user_123'));

// Only User A's admin data
await cache.invalidateByContext(
  const CacheContext(userId: 'user_123', role: 'admin'),
);

// Invalidate all users (CacheContext requires userId, so use clear for global)
await cache.clear();
```

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
  ttl: const Duration(minutes: 5),
);

// Logout
cache.clearContext();
await authService.logout();

// Login as Guest
cache.setContext(CacheContext(
  userId: 'guest_123',
  role: 'guest',
));

// Guest sees different data
final guestDashboard = await cache.get<Dashboard>(
  key: 'dashboard',
  fetcher: () => api.getGuestDashboard(),
  ttl: const Duration(minutes: 5),
);
```

---

## Best Practices

### Use Unique User IDs

```dart
// Bad
cache.setContext(CacheContext(userId: 'user'));

// Good
cache.setContext(CacheContext(userId: 'user_1234567890'));
```

### Clear Context on Logout

```dart
Future<void> logout() async {
  await cache.invalidateByContext(
    CacheContext(userId: currentUser.id),
  );
  cache.clearContext();
}
```

### Use Roles for Group Invalidation

```dart
// Invalidate a specific user's cache (role is used as part of the cache key prefix)
await cache.invalidateByContext(CacheContext(userId: 'user_123', role: 'admin'));
```

---

## Related

- [CacheNexusManager](cache-nexus-manager.md)
- [Security & Auth Guide](../guides/security-auth.md)
- [Auth Flow Example](../examples/auth-flow/)
