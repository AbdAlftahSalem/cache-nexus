# Offline Sync

The `SyncEngine` manages a persistent queue of tasks that retry automatically when connectivity returns.

---

## How It Works

1. Task is persisted to Hive (survives app restart)
2. If online, task is processed immediately
3. If offline, task stays in queue
4. When connectivity returns, all queued tasks are processed in order
5. Failed tasks retry up to **3 times**, then are dropped

---

## Setup

```dart
import 'package:smart_cache/smart_cache.dart';

final syncEngine = SyncEngine(
  executor: (task) async {
    // Execute the sync task (e.g., send to server)
    try {
      await http.post(
        Uri.parse(task.endpoint),
        body: jsonEncode(task.body),
      );
      return true; // success
    } catch (e) {
      return false; // will retry
    }
  },
  queueBoxName: 'offline_queue',
);

await syncEngine.init();
```

---

## Enqueue Tasks

```dart
await cache.enqueueSyncTask(SyncTask(
  id: 'order_001',
  key: 'order_001',
  endpoint: 'https://api.example.com/orders',
  method: 'POST',
  body: {'item': 'widget', 'quantity': 2},
  createdAt: DateTime.now(),
));
```

---

## SyncTask Properties

```dart
SyncTask({
  required String id,
  required String key,
  required String endpoint,
  required String method,
  dynamic body,
  required DateTime createdAt,
  int retryCount = 0,    // auto-incremented, max 3
})
```

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique task identifier |
| `key` | `String` | Cache key for this task |
| `endpoint` | `String` | API endpoint to call |
| `method` | `String` | HTTP method (GET, POST, PUT, DELETE) |
| `body` | `dynamic` | Request body |
| `createdAt` | `DateTime` | When task was created |
| `retryCount` | `int` | Current retry count (auto-incremented) |

---

## Example: Todo App

```dart
class TodoService {
  final SmartCacheManager _cache;
  final SyncEngine _syncEngine;

  TodoService(this._cache, this._syncEngine);

  // Create todo offline
  Future<void> createTodo(Todo todo) async {
    // Add to cache immediately (for instant UI)
    final todos = await _cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () => [],
    );
    await _cache.set<List<Todo>>(
      key: 'todos',
      data: [...todos, todo],
    );

    // Queue for sync when online
    await _cache.enqueueSyncTask(SyncTask(
      id: 'create_${todo.id}',
      key: 'todos',
      endpoint: 'https://api.example.com/todos',
      method: 'POST',
      body: todo.toJson(),
      createdAt: DateTime.now(),
    ));
  }

  // Delete todo offline
  Future<void> deleteTodo(String id) async {
    // Remove from cache immediately
    final todos = await _cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () => [],
    );
    await _cache.set<List<Todo>>(
      key: 'todos',
      data: todos.where((t) => t.id != id).toList(),
    );

    // Queue for sync when online
    await _cache.enqueueSyncTask(SyncTask(
      id: 'delete_$id',
      key: 'todos',
      endpoint: 'https://api.example.com/todos/$id',
      method: 'DELETE',
      body: id,
      createdAt: DateTime.now(),
    ));
  }
}
```

---

## NetworkStatus

Monitor network connectivity:

```dart
// Check current status
final isOnline = await NetworkStatus.isOnline;

// Listen for changes
NetworkStatus.onConnectivityChanged.listen((isOnline) {
  if (isOnline) {
    print('Back online! Processing queued tasks...');
  } else {
    print('Offline. Tasks will be queued.');
  }
});

// Mock for testing
NetworkStatus.setMockStatus(true);  // Force online
NetworkStatus.setMockStatus(false); // Force offline
NetworkStatus.setMockStatus(null);  // Reset to real status
```

---

## Complete Example: Offline-First App

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final hiveStorage = HiveCacheStorage(boxName: 'offline_app');
  await hiveStorage.init();

  // Initialize sync engine
  final syncEngine = SyncEngine(
    executor: (task) async {
      try {
        final response = await http.post(
          Uri.parse(task.endpoint),
          body: jsonEncode(task.body),
        );
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    },
    queueBoxName: 'sync_queue',
  );
  await syncEngine.init();

  // Initialize cache
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: hiveStorage,
    syncEngine: syncEngine,
  );

  runApp(MyApp(cache: cache));
}
```

---

## Best Practices

### Use Unique Task IDs

```dart
// Bad: generic ID
SyncTask(id: 'task_1', ...)

// Good: unique ID
SyncTask(id: 'create_${DateTime.now().millisecondsSinceEpoch}', ...)
```

### Handle Failures

Pass error handling via the executor when creating the SyncEngine:

```dart
final syncEngine = SyncEngine(
  executor: (task) async {
    try {
      await api.call(task);
      return true;
    } on NetworkException {
      return false; // Will retry
    } on ServerException {
      return false; // Will retry
    } on AuthException {
      return false; // Will retry (maybe token expired)
    }
  },
);
```

### Monitor Queue

```dart
// Process queue manually
await syncEngine.processQueue();
```

---

## Next Steps

- [Dev Tools](dev-tools.md) - Debug overlay and event monitoring
- [Blog App Example](../examples/blog-app/) - Complete offline-first example
- [Offline Todo Example](../examples/offline-todo/) - Offline CRUD with sync
