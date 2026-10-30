# Offline Sync

The `SyncEngine` manages a persistent queue of tasks that retry automatically when connectivity returns.

---

## How It Works

1. The task is persisted to Hive (survives an app restart). Its `body` must be JSON-like (`Map`, `List`, `String`, `num`, `bool`); objects with a `toJson()` method are converted when enqueued.
2. If online, the queue is processed immediately, oldest task first.
3. If offline, the task stays in the queue.
4. When connectivity returns, the queue is processed again. Tasks added while a pass is running are sent in that same pass.
5. An attempt **fails** when the executor returns `false` **or throws** (e.g. a `DioException`). A failing task never blocks the tasks behind it.
6. A failed task is retried up to `maxRetries` times (default 3). With `retryDelay` set, retries back off exponentially (`retryDelay`, 2×, 4×, … capped at `maxRetryDelay`) and are scheduled automatically.
7. After `maxRetries` failures the task is parked in `failedTasks` and announced on `onTaskFailed`. Call `retryFailed()` to give it a fresh set of attempts, or `deleteTask(id)` to drop it.

---

## Setup

```dart
import 'package:cache_nexus/cache_nexus.dart';

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
      return false; // will retry (throwing is fine too)
    }
  },
  queueBoxName: 'offline_queue',
  maxRetries: 5,
  retryDelay: const Duration(seconds: 2), // 2s, 4s, 8s, ... (max 5 min)
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
  int retryCount = 0,         // failed attempts so far
  DateTime? nextAttemptAt,    // set by backoff
  String? lastError,          // why the last attempt failed
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
| `retryCount` | `int` | Failed attempts so far |
| `nextAttemptAt` | `DateTime?` | Earliest next attempt (backoff) |
| `lastError` | `String?` | Why the last attempt failed |

---

## Example: Todo App

```dart
class TodoService {
  final CacheNexusManager _cache;
  final SyncEngine _syncEngine;

  TodoService(this._cache, this._syncEngine) {
    // Without this, List<Todo> cannot be rebuilt from disk after a restart.
    _cache.registerAdapter<Todo>(
      CacheAdapter.json(fromJson: Todo.fromJson, toJson: (t) => t.toJson()),
    );
  }

  // Create todo offline
  Future<void> createTodo(Todo todo) async {
    // Add to cache immediately (for instant UI)
    final todos = await _cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () async => <Todo>[],
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
      fetcher: () async => <Todo>[],
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
  final cache = CacheNexusManager(
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
    // Any other exception also counts as a failed attempt.
  },
);
```

### Monitor Queue

```dart
// Listen for real-time queue changes
syncEngine.onQueueChanged.listen((tasks) {
  print('Queue has ${tasks.length} tasks');
  for (final task in tasks) {
    print('  ${task.method} ${task.endpoint} (retries: ${task.retryCount})');
  }
});

// Get current tasks, and the ones that gave up
final pending = syncEngine.pendingTasks;
final failed = syncEngine.failedTasks;
syncEngine.onTaskFailed.listen((task) => print('gave up: ${task.lastError}'));

// Retry the parked ones (e.g. from a "Retry" button)
await syncEngine.retryFailed();

// Delete a specific task
await syncEngine.deleteTask('task_id');

// Clear all tasks
await syncEngine.clearQueue();
```

---

## Next Steps

- [Dev Tools](dev-tools.md) - Debug overlay and event monitoring
- [Blog App Example](../examples/blog-app/) - Complete offline-first example
- [Offline Todo Example](../examples/offline-todo/) - Offline CRUD with sync
