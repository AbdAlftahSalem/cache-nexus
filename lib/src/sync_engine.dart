import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'sync_task.dart';
import 'network_status.dart';

typedef SyncTaskExecutor = Future<bool> Function(SyncTask task);

class SyncEngine {
  final String queueBoxName;
  late Box _queueBox;
  final SyncTaskExecutor executor;
  bool _isProcessing = false;
  StreamSubscription? _connectivitySubscription;

  SyncEngine({
    required this.executor,
    this.queueBoxName = 'sync_queue',
  });

  Future<void> init() async {
    _queueBox = await Hive.openBox(queueBoxName);
    _connectivitySubscription = NetworkStatus.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        processQueue();
      }
    });
    
    // Initial check
    if (await NetworkStatus.isOnline) {
      processQueue();
    }
  }

  Future<void> enqueue(SyncTask task) async {
    await _queueBox.put(task.id, task.toJson());
    if (await NetworkStatus.isOnline) {
      await processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final tasks = _queueBox.values.map((v) => SyncTask.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      
      // Sort by creation date
      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final task in tasks) {
        if (!(await NetworkStatus.isOnline)) break;

        final success = await executor(task);
        if (success) {
          await _queueBox.delete(task.id);
        } else {
          task.retryCount++;
          if (task.retryCount >= 3) {
            // Log or handle max retries (maybe move to dead letter queue)
            await _queueBox.delete(task.id);
          } else {
            await _queueBox.put(task.id, task.toJson());
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
