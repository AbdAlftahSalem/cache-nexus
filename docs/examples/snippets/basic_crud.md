# Basic CRUD

Create, read, update, and delete cache entries.

---

## Create (Store)

```dart
// Store a string
await cache.set<String>(
  key: 'token',
  data: 'abc123',
);

// Store with TTL (expires after 1 hour)
await cache.set<String>(
  key: 'token',
  data: 'abc123',
  ttl: const Duration(hours: 1),
);

// Store a list
await cache.set<List<User>>(
  key: 'users',
  data: [User('Alice'), User('Bob')],
  ttl: const Duration(minutes: 30),
);

// Store a map
await cache.set<Map<String, dynamic>>(
  key: 'config',
  data: {'theme': 'dark', 'language': 'en'},
);
```

---

## Read (Get)

```dart
// Get with fetcher (fetches if not cached)
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () async {
    final response = await http.get(Uri.parse('https://api.example.com/users'));
    return jsonDecode(response.body);
  },
  ttl: const Duration(minutes: 30),
);

// Get without fetcher (returns null if not cached)
final token = await cache.get<String>(
  key: 'token',
  fetcher: () => null,
);

// Get with cacheFirst policy (default)
final data = await cache.get<String>(
  key: 'data',
  fetcher: () => fetchData(),
  policy: CachePolicy.cacheFirst,
);
```

---

## Update

```dart
// Update by setting again
await cache.set<String>(
  key: 'token',
  data: 'new_token_value',
);

// Update with fresh data from API
final users = await cache.get<List<User>>(
  key: 'users',
  fetcher: () => api.getUsers(),
  policy: CachePolicy.networkFirst, // Always fetch fresh
);
```

---

## Delete

```dart
// Delete a specific key
await cache.delete(key: 'token');

// Delete multiple keys
await cache.delete(key: 'users');
await cache.delete(key: 'config');

// Delete by prefix (all keys starting with 'user_')
await cache.deleteByPrefix('user_');
```

---

## Clear All

```dart
// Clear everything
await cache.clear();
```

---

## Check if Key Exists

```dart
// Get without fetcher
final data = await cache.get<String>(key: 'token', fetcher: () => null);

if (data != null) {
  print('Token exists');
} else {
  print('Token not found');
}
```

---

## Next Snippets

- [Custom Encryptor](custom_encryptor.md)
- [Cache Warming](cache_warming.md)
- [Testing Patterns](testing_patterns.md)
