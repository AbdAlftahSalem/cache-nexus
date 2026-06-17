import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'sync_task.dart';
import 'network_status.dart';

typedef SyncTaskExecutor = Future<bool> Function(SyncTask task);

class SyncEngine {
  final String queueBoxName;
  late Box<dynamic> _queueBox;
  final SyncTaskExecutor executor;
  bool _isProcessing = false;
  StreamSubscription<dynamic>? _connectivitySubscription;
  final StreamController<List<SyncTask>> _queueController =
      StreamController<List<SyncTask>>.broadcast();

  SyncEngine({
    required this.executor,
    this.queueBoxName = 'sync_queue',
    this.initHive = true,
  });

  final bool initHive;

  Future<void> init() async {
    if (initHive) {
      await Hive.initFlutter();
    }
    _queueBox = await Hive.openBox(queueBoxName);
    _connectivitySubscription = NetworkStatus.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        processQueue();
      }
    });

    if (await NetworkStatus.isOnline) {
      processQueue();
    }
  }

  Stream<List<SyncTask>> get onQueueChanged => _queueController.stream;

  List<SyncTask> get pendingTasks {
    final tasks = _queueBox.values
        .map((v) => SyncTask.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return tasks;
  }

  Future<int> get queueLength async => _queueBox.length;

  Future<void> _emitQueueChanged() async {
    if (!_queueController.isClosed) {
      _queueController.add(pendingTasks);
    }
  }

  Future<void> enqueue(SyncTask task) async {
    await _queueBox.put(task.id, task.toJson());
    await _emitQueueChanged();
    if (await NetworkStatus.isOnline) {
      await processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final tasks = _queueBox.values
          .map((v) => SyncTask.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();

      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final task in tasks) {
        if (!(await NetworkStatus.isOnline)) break;

        if (task.retryCount >= 3) continue;

        final success = await executor(task);
        if (success) {
          await _queueBox.delete(task.id);
        } else {
          task.retryCount++;
          await _queueBox.put(task.id, task.toJson());
        }

        await _emitQueueChanged();
      }
    } finally {
      _isProcessing = false;
      await _emitQueueChanged();
    }
  }

  Future<bool> deleteTask(String id) async {
    if (!_queueBox.containsKey(id)) return false;
    await _queueBox.delete(id);
    await _emitQueueChanged();
    return true;
  }

  Future<void> clearQueue() async {
    await _queueBox.clear();
    await _emitQueueChanged();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _queueController.close();
  }
}
