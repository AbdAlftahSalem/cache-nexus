# CacheNexusBuilder

A Flutter widget that automatically rebuilds when a cache key changes.

---

## Constructor

```dart
CacheNexusBuilder<T>({
  required CacheNexusManager cache,
  required String cacheKey,
  required Widget Function(BuildContext, T?) builder,
  Duration? debounce,
  WidgetBuilder? loadingBuilder,
  Widget Function(BuildContext, Object error, T? lastValue)? errorBuilder,
  void Function(Object error, StackTrace stackTrace)? onError,
})
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `cache` | `CacheNexusManager` | Cache instance |
| `cacheKey` | `String` | Key to watch |
| `builder` | `Widget Function(BuildContext, T?)` | Builder function |
| `debounce` | `Duration?` | Debounce interval |
| `loadingBuilder` | `WidgetBuilder?` | Shown until the first value arrives (otherwise `builder` gets `null`) |
| `errorBuilder` | `Widget Function(BuildContext, Object, T?)?` | Shown when the stream reports an error, e.g. a cached value that cannot be read as `T` |
| `onError` | `void Function(Object, StackTrace)?` | Called for every stream error |

Without `errorBuilder` and `onError`, errors are reported through `FlutterError.reportError` and the last good value stays on screen.

The builder only **watches** the key; load the data with `cache.get(...)` (for example in your repository or `initState`).

---

## Loading and errors

```dart
CacheNexusBuilder<List<User>>(
  cache: cache,
  cacheKey: 'users',
  loadingBuilder: (context) => const CircularProgressIndicator(),
  errorBuilder: (context, error, lastUsers) => Text('Could not read users: $error'),
  builder: (context, users) => UserList(users: users ?? const []),
);
```

---

## Basic Usage

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

---

## With Debounce

```dart
CacheNexusBuilder<List<Message>>(
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

1. `CacheNexusBuilder` subscribes to `cache.watch(cacheKey)`
2. On subscription it receives the current value (or `null`); other watchers are not notified again
3. Every `set()`, successful fetch, `delete()`, `clear()` or `invalidateByContext()` notifies the watchers of that key exactly once (`null` for removals)
4. `CacheNexusBuilder` rebuilds with the new value

---

## Example: Chat App

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
CacheNexusBuilder<User>(
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
CacheNexusBuilder<int>(
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
  data: (await cache.get<int>(key: 'counter', fetcher: () async => 0)) + 1,
);
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

`CacheNexusBuilder` automatically cleans up subscriptions when the widget is disposed. No manual cleanup needed.

---

## Related

- [CacheNexusManager](cache-nexus-manager.md)
- [Reactive Streams Guide](../guides/reactive-streams.md)
