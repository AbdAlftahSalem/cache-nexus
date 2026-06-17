# Cache Policies

Smart Cache supports 5 cache strategies. Choose the right one based on your data freshness requirements.

---

## Quick Decision Matrix

| Policy | Cache | Network | Fallback on Error | Best For |
|--------|-------|---------|-------------------|----------|
| `cacheFirst` | Check first | On miss | -- | Static data (profile, settings) |
| `networkFirst` | Fallback | Try first | Return cache | Real-time with offline (feed) |
| `cacheOnly` | Read only | Never | -- | Offline-only data, local drafts |
| `networkOnly` | Ignored | Always | -- | Critical real-time (payments) |
| `staleWhileRevalidate` | Return instantly | Background | -- | Instant UI (products) |

---

## cacheFirst (Default)

Check cache first. If hit, return. If miss or expired, fetch from network.

```dart
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: Duration(minutes: 30),
  policy: CachePolicy.cacheFirst,
);
```

### Flow

```
Request → Cache Hit? → Yes → Return cached data
                     → No  → Fetch from network → Store in cache → Return data
```

### When to use

- Data that doesn't change often
- User profile, settings, configuration
- Data that's expensive to fetch

### Pros

- Fast (cache hit is instant)
- Reduces network usage
- Works offline (if cached)

### Cons

- Stale data possible (depends on TTL)
- First request is slow (cache miss)

---

## networkFirst

Try network first. If it fails (e.g., offline), fall back to cache.

```dart
final feed = await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  ttl: Duration(minutes: 5),
  policy: CachePolicy.networkFirst,
);
```

### Flow

```
Request → Fetch from network → Success? → Yes → Store in cache → Return data
                                      → No  → Cache Hit? → Yes → Return cached
                                                           → No  → Return null
```

### When to use

- Real-time data that should be fresh
- Feed, notifications, messages
- Data that needs to be current

### Pros

- Always gets fresh data
- Works offline (fallback to cache)
- Good UX (shows something even offline)

### Cons

- Slower (network request every time)
- Uses more data

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

### When to use

- Offline-only data
- Local drafts, saved articles
- Data that should never be fetched from network

### Pros

- Fastest (no network)
- No data usage
- Guaranteed offline

### Cons

- Data must be pre-cached
- Never updates from network

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

### When to use

- Critical real-time data
- Payment status, OTP, verification codes
- Data that must never be stale

### Pros

- Always fresh
- No stale data

### Cons

- Slowest (network every time)
- Uses most data
- No offline support

---

## staleWhileRevalidate

Return cached data instantly, then refresh in the background.

```dart
final products = await cache.get<List<Product>>(
  key: 'products',
  fetcher: () => api.getProducts(),
  ttl: Duration(minutes: 10),
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

### When to use

- Show stale data immediately, update silently
- Product listings, search results
- Data that can be slightly outdated

### Pros

- Instant UI (shows data immediately)
- Always updating in background
- Good UX

### Cons

- First request is slow (no cache)
- Data may be slightly stale

---

## Combining Policies

You can use different policies for different data types:

```dart
// Profile: cache first (rarely changes)
final profile = await cache.get<User>(
  key: 'profile',
  fetcher: () => api.getProfile(),
  ttl: Duration(hours: 1),
  policy: CachePolicy.cacheFirst,
);

// Feed: network first (should be fresh)
final feed = await cache.get<List<Post>>(
  key: 'feed',
  fetcher: () => api.getFeed(),
  ttl: Duration(minutes: 5),
  policy: CachePolicy.networkFirst,
);

// Payment: network only (critical)
final payment = await cache.get<Payment>(
  key: 'payment_$id',
  fetcher: () => api.getPayment(id),
  policy: CachePolicy.networkOnly,
);

// Products: stale while revalidate (instant UI)
final products = await cache.get<List<Product>>(
  key: 'products',
  fetcher: () => api.getProducts(),
  ttl: Duration(minutes: 10),
  policy: CachePolicy.staleWhileRevalidate,
);
```

---

## Next Steps

- [Two-Tier Storage](two-tier-storage.md) - Memory + Hive architecture
- [Security & Auth](security-auth.md) - Encryption and user isolation
- [Reactive Streams](reactive-streams.md) - Watch API and widgets
