import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import 'models/todo.dart';
import 'services/todo_service.dart';
import 'screens/todo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final hiveStorage = HiveCacheStorage(boxName: 'offline_todos');
  await hiveStorage.init();

  // Initialize sync engine
  final syncEngine = SyncEngine(
    executor: (task) async {
      // Simulate API call
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(seconds: 1));
      print('Syncing task: ${task.id}');
      return true; // Always succeed in demo
    },
    queueBoxName: 'todo_sync_queue',
    retryDelay: const Duration(seconds: 2),
  );
  await syncEngine.init();

  // Initialize cache
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: hiveStorage,
    syncEngine: syncEngine,
    mode: CacheNexusMode.dev,
  );

  // Required for offline-first data: without it List<Todo> cannot be rebuilt
  // from disk after a restart, and the saved todos would be lost.
  cache.registerAdapter<Todo>(
    CacheAdapter.json(fromJson: Todo.fromJson, toJson: (t) => t.toJson()),
  );

  runApp(OfflineTodoApp(cache: cache, syncEngine: syncEngine));
}

class OfflineTodoApp extends StatelessWidget {
  final CacheNexusManager cache;
  final SyncEngine syncEngine;

  const OfflineTodoApp({
    super.key,
    required this.cache,
    required this.syncEngine,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Todo Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: CacheNexusOverlay(
        manager: cache,
        child: TodoService(
          cache: cache,
          syncEngine: syncEngine,
          child: const TodoScreen(),
        ),
      ),
    );
  }
}
