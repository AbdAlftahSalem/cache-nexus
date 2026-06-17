# SmartCacheBuilder

A Flutter widget that automatically rebuilds when a cache key changes.

---

## Constructor

```dart
SmartCacheBuilder<T>({
  required SmartCacheManager cache,
  required String cacheKey,
  required Widget Function(BuildContext, T?) builder,
  Duration? debounce,
})
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `cache` | `SmartCacheManager` | Cache instance |
| `cacheKey` | `String` | Key to watch |
| `builder` | `Widget Function(BuildContext, T?)` | Builder function |
| `debounce` | `Duration?` | Debounce interval |

---

## Basic Usage

```dart
SmartCacheBuilder<List<User>>(
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

---

## With Debounce

```dart
SmartCacheBuilder<List<Message>>(
  cache: cache,
  cacheKey: 'messages',
  debounce: const Duration(milliseconds: 500),
  builder: (context, messages) {
    if (messages == null) return const SizedBox();
    return MessageList(messages: messages);
  },
);
```

---

## How It Works

1. `SmartCacheBuilder` subscribes to `cache.watch(cacheKey)`
2. On subscription, the current value (if any) is emitted immediately
3. When `set()` or `delete()` is called, all subscribers for that key are notified
4. `SmartCacheBuilder` listens to this stream and rebuilds

---

## Example: Chat App

```dart
class ChatScreen extends StatelessWidget {
  final SmartCacheManager cache;

  const ChatScreen({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: SmartCacheBuilder<List<Message>>(
        cache: cache,
        cacheKey: 'messages',
        debounce: const Duration(milliseconds: 300),
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

## Example: User Profile

```dart
SmartCacheBuilder<User>(
  cache: cache,
  cacheKey: 'profile',
  builder: (context, user) {
    if (user == null) {
      return const CircleAvatar(child: Icon(Icons.person));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(user.avatarUrl),
    );
  },
);
```

---

## Example: Counter

```dart
SmartCacheBuilder<int>(
  cache: cache,
  cacheKey: 'counter',
  builder: (context, count) {
    return Text(
      'Count: ${count ?? 0}',
      style: const TextStyle(fontSize: 24),
    );
  },
);

// Increment counter
await cache.set<int>(
  key: 'counter',
  data: (await cache.get<int>(key: 'counter', fetcher: () => 0))! + 1,
);
```

---

## Multiple Watchers

You can watch the same key from multiple places:

```dart
// Widget A
SmartCacheBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserList(users: users),
);

// Widget B (also watches 'users')
SmartCacheBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  builder: (context, users) => UserCount(count: users?.length ?? 0),
);

// When 'users' is updated, BOTH widgets rebuild
```

---

## Cleanup

`SmartCacheBuilder` automatically cleans up subscriptions when the widget is disposed. No manual cleanup needed.

---

## Related

- [SmartCacheManager](smart-cache-manager.md)
- [Reactive Streams Guide](../guides/reactive-streams.md)
