# SyncEngine

Offline sync queue for persistent task execution.

---

## Constructor

```dart
SyncEngine({
  required SyncTaskExecutor executor,
  String queueBoxName = 'sync_queue',
  bool initHive = true,
})
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `executor` | `SyncTaskExecutor` | - | Function to execute tasks |
| `queueBoxName` | `String` | `'sync_queue'` | Hive box name for queue |

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

Process all pending tasks in the queue. Tasks with `retryCount >= 3` are skipped (they remain in the queue for UI visibility).

**Example:**

```dart
await syncEngine.processQueue();
```

---

### enqueue

```dart
Future<void> enqueue(SyncTask task)
```

Add a task to the sync queue. If online, processes immediately.

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

Clean up resources and close streams.

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

Returns all current tasks sorted by `createdAt` ascending.

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
| `retryCount` | `int` | `0` | Current retry count (auto-incremented, max 3) |

---

## How It Works

1. Task is persisted to Hive (survives app restart)
2. If online, task is processed immediately
3. If offline, task stays in queue
4. When connectivity returns, all queued tasks are processed in order
5. Failed tasks retry up to **3 times**, then are skipped (remain in queue for UI visibility, can be deleted manually)

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
      return false; // will retry
    }
  },
  queueBoxName: 'offline_queue',
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
  final SmartCacheManager _cache;
  final SyncEngine _syncEngine;

  TodoService(this._cache, this._syncEngine);

  Future<void> createTodo(Todo todo) async {
    // Add to cache immediately
    final todos = await _cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () => [],
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
      fetcher: () => [],
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

- [SmartCacheManager](smart-cache-manager.md)
- [Offline Sync Guide](../guides/offline-sync.md)
- [Offline Todo Example](../examples/offline-todo/)
