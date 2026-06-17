import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
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
      await Future.delayed(const Duration(seconds: 1));
      print('Syncing task: ${task.id}');
      return true; // Always succeed in demo
    },
    queueBoxName: 'todo_sync_queue',
  );
  await syncEngine.init();

  // Initialize cache
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: hiveStorage,
    syncEngine: syncEngine,
    mode: SmartCacheMode.dev,
  );

  runApp(OfflineTodoApp(cache: cache, syncEngine: syncEngine));
}

class OfflineTodoApp extends StatelessWidget {
  final SmartCacheManager cache;
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
      home: SmartCacheOverlay(
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
