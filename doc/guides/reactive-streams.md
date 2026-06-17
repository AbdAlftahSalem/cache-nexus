# Reactive Streams

Smart Cache supports **reactive programming** -- watch cache keys and get notified when data changes.

---

## watch() API

Subscribe to a cache key and receive updates when data changes:

```dart
// Watch a cache key for changes
cache.watch<List<User>>('users').listen((users) {
  if (users != null) {
    print('Users updated: ${users.length}');
  } else {
    print('Users deleted or not found');
  }
});

// Update the cache -- all watchers are notified automatically
await cache.set(key: 'users', data: [User('Alice'), User('Bob')]);
```

### How It Works

1. `watch(key)` subscribes to a broadcast `StreamController` for that key
2. On subscription, the current value (if any) is emitted immediately
3. When `set()` or `delete()` is called, all subscribers for that key are notified
4. `CacheNexusBuilder` listens to this stream and calls `setState()` on updates

---

## watch() with Debounce

Prevent rapid UI rebuilds during fast updates:

```dart
cache.watch<List<Product>>(
  'products',
  debounce: Duration(milliseconds: 300),
).listen((products) {
  setState(() => _products = products);
});
```

### When to use debounce

- Search results that update as user types
- Real-time data that changes frequently
- Preventing excessive rebuilds

---

## CacheNexusBuilder Widget

A Flutter widget that **automatically rebuilds** when a cache key changes:

```dart
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) {
    if (users == null) {
      return const CircularProgressIndicator();
    }
    return ListView(
      children: users.map((u) => Text(u.name)).toList(),
    );
  },
);
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `cache` | `CacheNexusManager` | Cache instance |
| `cacheKey` | `String` | Key to watch |
| `builder` | `Widget Function(BuildContext, T?)` | Builder function |
| `debounce` | `Duration?` | Debounce interval |

---

## CacheNexusBuilder with Debounce

```dart
CacheNexusBuilder<List<Message>>(
  cache: cache,
  cacheKey: 'messages',
  debounce: Duration(milliseconds: 500),
  builder: (context, messages) {
    if (messages == null) return const SizedBox();
    return MessageList(messages: messages);
  },
);
```

---

## Real-World Example: Chat App

```dart
class ChatScreen extends StatelessWidget {
  final CacheNexusManager cache;

  const ChatScreen({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: CacheNexusBuilder<List<Message>>(
        cache: cache,
        cacheKey: 'messages',
        debounce: Duration(milliseconds: 300),
        builder: (context, messages) {
          if (messages == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (messages.isEmpty) {
            return const Center(child: Text('No messages'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
                title: Text(message.text),
                subtitle: Text(message.sender),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## Updating the Cache

When you update the cache, all watchers are automatically notified:

```dart
// Send a new message
await cache.set<List<Message>>(
  key: 'messages',
  data: [...existingMessages, newMessage],
);

// All CacheNexusBuilder widgets watching 'messages' will rebuild
```

---

## Multiple Watchers

You can watch the same key from multiple places:

```dart
// Widget A
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserList(users: users),
);

// Widget B (also watches 'users')
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserCount(count: users?.length ?? 0),
);

// When 'users' is updated, BOTH widgets rebuild
```

---

## Cleanup

CacheNexusBuilder automatically cleans up subscriptions when the widget is disposed. No manual cleanup needed.

---

## Next Steps

- [Offline Sync](offline-sync.md) - SyncEngine for offline-first apps
- [Dev Tools](dev-tools.md) - Debug overlay and event monitoring
- [Blog App Example](../examples/blog-app/) - Complete reactive UI example
