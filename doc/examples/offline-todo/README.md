# Offline Todo Example

A complete offline-first todo app demonstrating Smart Cache's SyncEngine for offline CRUD operations with automatic sync when online.

## Features Demonstrated

- **Offline-First**: Create, edit, delete todos without network
- **SyncEngine**: Persistent queue with automatic retry
- **NetworkStatus**: Monitor connectivity changes
- **Persistent Storage**: Todos survive app restart
- **Reactive UI**: Auto-updating list with watch()

## Flow

1. **Create Todo**: Added to cache immediately (instant UI), queued for sync
2. **Delete Todo**: Removed from cache immediately, queued for sync
3. **Go Offline**: Toggle network status to simulate offline
4. **Come Back Online**: Queued tasks automatically sync

## Code Snippets

### Initialize Cache + SyncEngine

```dart
// Initialize storage
final hiveStorage = HiveCacheStorage(boxName: 'offline_todos');
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
      return false; // Will retry
    }
  },
  queueBoxName: 'todo_sync_queue',
);
await syncEngine.init();

// Initialize cache
final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: hiveStorage,
  syncEngine: syncEngine,
);
```

### Create Todo (Offline-First)

```dart
Future<void> createTodo(Todo todo) async {
  // 1. Add to cache immediately (instant UI update)
  final todos = await _cache.get<List<Todo>>(
    key: 'todos',
    fetcher: () => [],
  );
  await _cache.set<List<Todo>>(
    key: 'todos',
    data: [...todos, todo],
  );

  // 2. Queue for sync when online
  await _cache.enqueueSyncTask(SyncTask(
    id: 'create_${todo.id}',
    key: 'todos',
    endpoint: 'https://api.example.com/todos',
    method: 'POST',
    body: todo.toJson(),
    createdAt: DateTime.now(),
  ));
}
```

### Delete Todo (Offline-First)

```dart
Future<void> deleteTodo(String id) async {
  // 1. Remove from cache immediately
  final todos = await _cache.get<List<Todo>>(
    key: 'todos',
    fetcher: () => [],
  );
  await _cache.set<List<Todo>>(
    key: 'todos',
    data: todos.where((t) => t.id != id).toList(),
  );

  // 2. Queue for sync when online
  await _cache.enqueueSyncTask(SyncTask(
    id: 'delete_$id',
    key: 'todos',
    endpoint: 'https://api.example.com/todos/$id',
    method: 'DELETE',
    body: id,
    createdAt: DateTime.now(),
  ));
}
```

### Monitor Network Status

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
```

### Todo Screen

```dart
class TodoScreen extends StatelessWidget {
  final CacheNexusManager cache;

  const TodoScreen({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Todos')),
      body: CacheNexusBuilder<List<Todo>>(
        cache: cache,
        cacheKey: 'todos',
        builder: (context, todos) {
          if (todos == null || todos.isEmpty) {
            return const Center(child: Text('No todos yet'));
          }
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return ListTile(
                title: Text(todo.title),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteTodo(todo.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTodo(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## Running

```bash
flutter run
```

## Testing Offline Behavior

1. Add some todos (they sync immediately if online)
2. Toggle the "Online" switch to OFF
3. Add more todos (they appear instantly in the list)
4. Toggle back to ON
5. Watch queued tasks sync automatically

## Dependencies

- `cache_nexus`: Cache + SyncEngine
- `hive_flutter`: Persistent storage
- `connectivity_plus`: Network status
