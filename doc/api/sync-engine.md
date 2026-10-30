# SyncEngine

Offline sync queue for persistent task execution.

---

## Constructor

```dart
SyncEngine({
  required SyncTaskExecutor executor,
  String queueBoxName = 'sync_queue',
  bool initHive = true,
  int maxRetries = 3,
  Duration retryDelay = Duration.zero,
  Duration maxRetryDelay = const Duration(minutes: 5),
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `executor` | `SyncTaskExecutor` | - | Sends one task; return `true` on success. Returning `false` or throwing counts as a failed attempt |
| `queueBoxName` | `String` | `'sync_queue'` | Hive box name for the queue |
| `initHive` | `bool` | `true` | Call `Hive.initFlutter()` in `init()` |
| `maxRetries` | `int` | `3` | Failed attempts before a task is parked in `failedTasks` |
| `retryDelay` | `Duration` | `zero` | Base backoff. `zero` retries on the next trigger (enqueue, reconnect, `processQueue()`); otherwise retries are scheduled at `retryDelay × 2^(attempt-1)` |
| `maxRetryDelay` | `Duration` | `5 min` | Cap for the backoff |

---

## Methods

### init

```dart
Future<void> init()
```

Initialize the sync engine. Must call before use.

**Example:**

```dart
await syncEngine.init();
```

---

### processQueue

```dart
Future<void> processQueue()
```

Delivers every due task. Parked tasks (`retryCount >= maxRetries`) and tasks waiting for their backoff are skipped. If a pass is already running, this returns immediately and the running pass also delivers tasks added in the meantime.

**Example:**

```dart
await syncEngine.processQueue();
```

---

### enqueue

```dart
Future<void> enqueue(SyncTask task)
```

Add a task to the sync queue (a task with the same `id` is replaced). If online, processes the queue immediately. Never throws because of a failing executor.

---

### retryFailed

```dart
Future<int> retryFailed({String? id})
```

Gives parked tasks (or only `id`) a fresh set of retries and starts delivering. Returns how many tasks were reset.

---

### deleteTask

```dart
Future<bool> deleteTask(String id)
```

Remove a specific task by ID. Returns `true` if deleted, `false` if not found.

---

### clearQueue

```dart
Future<void> clearQueue()
```

Remove all tasks from the sync queue.

---

### dispose

```dart
void dispose()
```

Stops delivery (a running pass stops after its current task), cancels scheduled retries and closes the streams. `CacheNexusManager.dispose()` calls it for you.

**Example:**

```dart
syncEngine.dispose();
```

---

## Properties

### onQueueChanged

```dart
Stream<List<SyncTask>> get onQueueChanged
```

Broadcast stream that emits the current task list after every queue mutation (enqueue, process, delete, clear). Useful for real-time UI updates.

### pendingTasks

```dart
List<SyncTask> get pendingTasks
```

Returns all queued tasks (including parked ones) sorted by `createdAt` ascending.

### failedTasks / onTaskFailed

```dart
List<SyncTask> get failedTasks
Stream<SyncTask> get onTaskFailed
```

Tasks that exhausted `maxRetries`, and a stream that emits each one when it gets parked. Show them in your UI and offer "retry" (`retryFailed(id: ...)`) or "discard" (`deleteTask(id)`).

### isInitialized

```dart
bool get isInitialized
```

Whether `init()` has completed. Calling `enqueue`/`deleteTask`/`clearQueue` before that throws a `StateError`.

### queueLength

```dart
Future<int> get queueLength
```

Returns the number of tasks in the queue.

---

## SyncTask

### Constructor

```dart
SyncTask({
  required String id,
  required String key,
  required String endpoint,
  required String method,
  dynamic body,
  required DateTime createdAt,
  int retryCount = 0,
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | `String` | - | Unique task identifier |
| `key` | `String` | - | Cache key for this task |
| `endpoint` | `String` | - | API endpoint to call |
| `method` | `String` | - | HTTP method (GET, POST, PUT, DELETE) |
| `body` | `dynamic` | - | Request body |
| `createdAt` | `DateTime` | - | When task was created |
| `retryCount` | `int` | `0` | Failed attempts so far |
| `nextAttemptAt` | `DateTime?` | `null` | Earliest next attempt (set by backoff) |
| `lastError` | `String?` | `null` | Why the last attempt failed |

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

## Example: Basic Usage

```dart
final syncEngine = SyncEngine(
  executor: (task) async {
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

// Enqueue a task
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

  Future<void> createTodo(Todo todo) async {
    // Add to cache immediately
    final todos = await _cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () async => <Todo>[],
    );
    await _cache.set<List<Todo>>(
      key: 'todos',
      data: [...todos, todo],
    );

    // Queue for sync
    await _cache.enqueueSyncTask(SyncTask(
      id: 'create_${todo.id}',
      key: 'todos',
      endpoint: 'https://api.example.com/todos',
      method: 'POST',
      body: todo.toJson(),
      createdAt: DateTime.now(),
    ));
  }

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

    // Queue for sync
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

## Related

- [CacheNexusManager](cache-nexus-manager.md)
- [Offline Sync Guide](../guides/offline-sync.md)
- [Offline Todo Example](../examples/offline-todo/)
