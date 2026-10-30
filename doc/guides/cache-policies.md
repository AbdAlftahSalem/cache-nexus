# Cache Policies

Cache Nexus supports 5 cache strategies. Choose the right one based on your data freshness requirements.

---

## Quick Decision Matrix

| Policy | Cache | Network | Fallback on Error | Best For |
|--------|-------|---------|-------------------|----------|
| `cacheFirst` | Check first | On miss | -- | Static data (profile, settings) |
| `networkFirst` | Fallback | Try first | Return cache | Real-time with offline (feed) |
| `cacheOnly` | Read only | Never | -- | Offline-only data, local drafts |
| `networkOnly` | Ignored | Always | -- | Critical real-time (payments) |
| `staleWhileRevalidate` | Return instantly (even expired) | Background | Keep cached value | Instant UI (products) |

### Exact semantics (1.1.0)

| Policy | Fresh entry | Expired entry | No entry | Fetcher throws |
|--------|-------------|---------------|----------|----------------|
| `cacheFirst` | returned | fetch | fetch | error reaches the caller |
| `networkFirst` | used only if the fetch fails | not used | - | fresh cached value, else the **original** network error is rethrown |
| `cacheOnly` | returned | `CacheMissException` (or `null` for nullable `T`) | `CacheMissException` (or `null`) | never called |
| `networkOnly` | ignored | ignored | ignored | error reaches the caller |
| `staleWhileRevalidate` | returned + background refresh | **returned** + background refresh | fetch | background: reported as an error event; foreground (no entry): reaches the caller |

Notes:

- Every successful fetch is stored (memory + persistent) and pushed to watchers, whatever the policy.
- A cached `null` (for `get<T?>`) is a hit; it is not fetched again until it expires.
- When offline, `networkFirst` reads the cache without calling the fetcher, and `staleWhileRevalidate` skips the background refresh.
- Concurrent calls for the same key share one fetch.
- An entry that exists but cannot be converted to `T` (for example a custom class without a registered `CacheAdapter`) is treated as a miss and reported as a `CacheDecodeException` error event and a debug log; `cacheOnly` throws it. See [Two-Tier Storage](two-tier-storage.md#typed-data-and-app-restarts).

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

Try the network first. If it fails, fall back to a fresh cached value; if there is none, the original network error (e.g. `DioException`) is rethrown so you can show a real message.

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
Request → Online? → No  → read cache (like cacheOnly)
        → Yes → Fetch from network → Success? → Yes → Store in cache → Return data
                                              → No  → Fresh cache hit? → Yes → Return cached
                                                                         → No  → Rethrow the network error
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
Request → Fresh cache hit? → Yes → Return cached data
                           → No  → throw CacheMissException (or return null when T is nullable)
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

Always fetch from the network. The cache is never read (the result is still stored, so watchers and other policies see it).

```dart
final status = await cache.get<PaymentStatus>(
  key: 'payment_123',
  fetcher: () => api.checkPayment('123'),
  policy: CachePolicy.networkOnly,
);
```

### Flow

```
Request → Fetch from network → Success? → Yes → Store in cache → Return data
                                      → No  → Rethrow the error
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

Return cached data instantly, **even if its TTL has passed**, then refresh in the background. Watchers (`watch()`, `CacheNexusBuilder`) receive the fresh value when it arrives.

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
Request → Cache Hit (fresh OR expired)? → Yes → Return it immediately
                                              → Fetch fresh data in background (when online)
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
