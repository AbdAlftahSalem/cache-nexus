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
| `cacheKeyPrefix` | `String` | Auto-generated prefix: `userId_role_` |

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

// User B (isolated)
cache.setContext(CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(
  key: 'secret',
  fetcher: () => 'Public Only',
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
// Invalidate only User A's cache
await cache.invalidateByContext(CacheContext(userId: 'user_123'));

// Invalidate all admin users
await cache.invalidateByContext(CacheContext(role: 'admin'));

// Invalidate all users
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
// Invalidate all users with a specific role
await cache.invalidateByContext(CacheContext(role: 'admin'));
```

---

## Related

- [SmartCacheManager](smart-cache-manager.md)
- [Security & Auth Guide](../guides/security-auth.md)
- [Auth Flow Example](../examples/auth-flow/)
