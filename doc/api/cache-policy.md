# CachePolicy

Cache strategy enum with 5 policies.

---

## Enum Values

```dart
enum CachePolicy {
  cacheFirst,
  networkFirst,
  cacheOnly,
  networkOnly,
  staleWhileRevalidate,
}
```

---

## cacheFirst

Check cache first. If hit, return. If miss or expired, fetch from network.

```dart
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: const Duration(minutes: 30),
  policy: CachePolicy.cacheFirst,
);
```

### Flow

```
Request → Cache Hit? → Yes → Return cached data
                     → No  → Fetch from network → Store in cache → Return data
```

### Best For

- Data that doesn't change often
- User profile, settings, configuration
- Data that's expensive to fetch

---

## networkFirst

Try network first. If it fails (e.g., offline), fall back to cache.

```dart
final feed = await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  ttl: const Duration(minutes: 5),
  policy: CachePolicy.networkFirst,
);
```

### Flow

```
Request → Fetch from network → Success? → Yes → Store in cache → Return data
                                      → No  → Cache Hit? → Yes → Return cached
                                                           → No  → Return null
```

### Best For

- Real-time data that should be fresh
- Feed, notifications, messages
- Data that needs to be current

---

## cacheOnly

Never hit the network. Return cached data or throw if missing.

```dart
final drafts = await cache.get<List<Draft>>(
  key: 'drafts',
  fetcher: () => throw Exception('Should not fetch'),
  policy: CachePolicy.cacheOnly,
);
```

### Flow

```
Request → Cache Hit? → Yes → Return cached data
                     → No  → Return null (or throw)
```

### Best For

- Offline-only data
- Local drafts, saved articles
- Data that should never be fetched from network

---

## networkOnly

Always fetch from network. Cache is ignored completely.

```dart
final status = await cache.get<PaymentStatus>(
  key: 'payment_123',
  fetcher: () => api.checkPayment('123'),
  policy: CachePolicy.networkOnly,
);
```

### Flow

```
Request → Fetch from network → Success? → Yes → Return data (don't cache)
                                      → No  → Return null
```

### Best For

- Critical real-time data
- Payment status, OTP, verification codes
- Data that must never be stale

---

## staleWhileRevalidate

Return cached data instantly, then refresh in the background.

```dart
final products = await cache.get<List<Product>>(
  key: 'products',
  fetcher: () => api.getProducts(),
  ttl: const Duration(minutes: 10),
  policy: CachePolicy.staleWhileRevalidate,
);
```

### Flow

```
Request → Cache Hit? → Yes → Return stale data immediately
                          → Fetch fresh data in background
                          → Update cache when done
                     → No  → Fetch from network → Store in cache → Return data
```

### Best For

- Show stale data immediately, update silently
- Product listings, search results
- Data that can be slightly outdated

---

## Decision Matrix

| Policy | Cache | Network | Fallback on Error | Best For |
|--------|-------|---------|-------------------|----------|
| `cacheFirst` | Check first | On miss | -- | Static data |
| `networkFirst` | Fallback | Try first | Return cache | Real-time with offline |
| `cacheOnly` | Read only | Never | -- | Offline data |
| `networkOnly` | Ignored | Always | -- | Critical real-time |
| `staleWhileRevalidate` | Return instantly | Background | -- | Instant UI |

---

## Related

- [SmartCacheManager](smart-cache-manager.md)
- [Cache Policies Guide](../guides/cache-policies.md)
