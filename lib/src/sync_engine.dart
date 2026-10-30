import 'dart:async';
import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'network_status.dart';
import 'sync_task.dart';
import 'type_registry.dart';

/// Sends a [SyncTask] to your backend. Return `true` when the server accepted
/// it. Returning `false` **or throwing** counts as a failed attempt.
typedef SyncTaskExecutor = Future<bool> Function(SyncTask task);

/// A persistent (Hive-backed) queue of offline writes.
///
/// Tasks are delivered oldest first whenever the device is online: on
/// [init], on every [enqueue], and whenever connectivity comes back. A task
/// whose executor returns `false` or throws is retried; after [maxRetries]
/// failed attempts it moves to [failedTasks] and is no longer retried
/// automatically (see [retryFailed]).
///
/// With a non-zero [retryDelay], retries back off exponentially
/// (`retryDelay * 2^(attempt-1)`, capped at [maxRetryDelay]) and are
/// scheduled automatically.
class SyncEngine {
  /// The Hive box that stores the queue.
  final String queueBoxName;
  Box<dynamic>? _queueBox;

  /// Delivers one task.
  final SyncTaskExecutor executor;

  /// Whether [init] calls `Hive.initFlutter()` first.
  final bool initHive;

  /// Failed attempts after which a task is parked in [failedTasks].
  final int maxRetries;

  /// Base delay before retrying a failed task. [Duration.zero] (the default)
  /// retries on the next trigger (enqueue, reconnect or [processQueue]).
  final Duration retryDelay;

  /// Upper bound for the exponential backoff.
  final Duration maxRetryDelay;

  bool _isProcessing = false;
  bool _rerunRequested = false;
  bool _disposed = false;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  final StreamController<List<SyncTask>> _queueController =
      StreamController<List<SyncTask>>.broadcast();
  final StreamController<SyncTask> _failedController =
      StreamController<SyncTask>.broadcast();

  /// Creates an engine. Call [init] before use.
  SyncEngine({
    required this.executor,
    this.queueBoxName = 'sync_queue',
    this.initHive = true,
    this.maxRetries = 3,
    this.retryDelay = Duration.zero,
    this.maxRetryDelay = const Duration(minutes: 5),
  }) : assert(maxRetries > 0, 'maxRetries must be at least 1');

  /// Whether [init] has completed.
  bool get isInitialized => _queueBox != null;

  Box<dynamic> get _box {
    final box = _queueBox;
    if (box == null) {
      throw StateError('SyncEngine not initialized. Call init() first.');
    }
    return box;
  }

  /// Opens the queue and starts listening for connectivity changes.
  Future<void> init() async {
    if (initHive) {
      await Hive.initFlutter();
    }
    _queueBox = await Hive.openBox<dynamic>(queueBoxName);
    _connectivitySubscription ??= NetworkStatus.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) unawaited(processQueue());
    });

    if (await NetworkStatus.isOnline) {
      unawaited(processQueue());
    }
  }

  /// Emits the pending tasks whenever the queue changes.
  Stream<List<SyncTask>> get onQueueChanged => _queueController.stream;

  /// Emits a task when it exhausts [maxRetries] and moves to [failedTasks].
  Stream<SyncTask> get onTaskFailed => _failedController.stream;

  List<SyncTask> get _allTasks {
    final box = _queueBox;
    if (box == null) return const [];
    final tasks = <SyncTask>[];
    for (final v in box.values) {
      try {
        tasks.add(
          SyncTask.fromJson(
            CacheTypeRegistry.normalize(v) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Skip unreadable rows instead of failing the whole queue.
      }
    }
    tasks.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return tasks;
  }

  /// Every queued task (oldest first), including [failedTasks].
  List<SyncTask> get pendingTasks => _allTasks;

  /// Tasks that exhausted [maxRetries] and wait for [retryFailed] or
  /// [deleteTask].
  List<SyncTask> get failedTasks =>
      _allTasks.where((t) => t.retryCount >= maxRetries).toList();

  /// The number of queued tasks (including failed ones).
  Future<int> get queueLength async => _queueBox?.length ?? 0;

  void _emitQueueChanged() {
    if (!_queueController.isClosed && _queueBox != null) {
      _queueController.add(_allTasks);
    }
  }

  /// Adds [task] to the queue and, when online, starts delivering.
  ///
  /// Never throws because of a failing executor; failures are recorded on
  /// the task instead.
  Future<void> enqueue(SyncTask task) async {
    final json = task.toJson();
    json['body'] = CacheTypeRegistry.toStorable(task.body);
    await _box.put(task.id, json);
    _emitQueueChanged();
    if (await NetworkStatus.isOnline) {
      await processQueue();
    }
  }

  /// Delivers every due task.
  ///
  /// Safe to call at any time. When a pass is already running, this call
  /// returns immediately and the running pass picks up any tasks added in
  /// the meantime before it finishes.
  Future<void> processQueue() {
    if (_disposed || _queueBox == null) return Future.value();
    if (_isProcessing) {
      _rerunRequested = true;
      return Future.value();
    }
    _isProcessing = true;
    return _run();
  }

  Future<void> _run() async {
    try {
      final attempted = <String>{};
      do {
        _rerunRequested = false;
        for (final task in _allTasks) {
          if (_disposed || !(await NetworkStatus.isOnline)) return;
          if (attempted.contains(task.id)) continue;
          if (task.retryCount >= maxRetries) continue;
          final next = task.nextAttemptAt;
          if (next != null && next.isAfter(DateTime.now())) continue;
          if (!_box.containsKey(task.id)) continue;

          attempted.add(task.id);
          await _attempt(task);
          _emitQueueChanged();
        }
      } while (_rerunRequested && !_disposed);
    } finally {
      _isProcessing = false;
      _emitQueueChanged();
      _scheduleRetry();
    }
  }

  Future<void> _attempt(SyncTask task) async {
    bool success;
    String? error;
    try {
      success = await executor(task);
      if (!success) error = 'executor returned false';
    } catch (e) {
      success = false;
      error = e.toString();
    }
    if (_disposed || _queueBox == null || !_box.isOpen) return;

    if (success) {
      await _box.delete(task.id);
      return;
    }

    task.retryCount++;
    task.lastError = error;
    if (retryDelay > Duration.zero && task.retryCount < maxRetries) {
      final factor = pow(2, task.retryCount - 1).toInt();
      var delay = retryDelay * factor;
      if (delay > maxRetryDelay) delay = maxRetryDelay;
      task.nextAttemptAt = DateTime.now().add(delay);
    } else {
      task.nextAttemptAt = null;
    }
    // The executor may have deleted the task meanwhile; don't resurrect it.
    if (_box.containsKey(task.id)) {
      await _box.put(task.id, task.toJson());
    }
    if (task.retryCount >= maxRetries && !_failedController.isClosed) {
      _failedController.add(task);
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed || retryDelay <= Duration.zero) return;
    DateTime? earliest;
    for (final t in _allTasks) {
      final next = t.nextAttemptAt;
      if (t.retryCount >= maxRetries || next == null) continue;
      if (earliest == null || next.isBefore(earliest)) earliest = next;
    }
    if (earliest == null) return;
    var wait = earliest.difference(DateTime.now());
    if (wait.isNegative) wait = Duration.zero;
    _retryTimer = Timer(wait, () => unawaited(processQueue()));
  }

  /// Gives failed tasks (or only the one with [id]) a fresh set of retries
  /// and starts delivering. Returns how many tasks were reset.
  Future<int> retryFailed({String? id}) async {
    var count = 0;
    for (final task in failedTasks) {
      if (id != null && task.id != id) continue;
      task
        ..retryCount = 0
        ..nextAttemptAt = null;
      await _box.put(task.id, task.toJson());
      count++;
    }
    _emitQueueChanged();
    if (count > 0 && await NetworkStatus.isOnline) await processQueue();
    return count;
  }

  /// Removes the task with [id]. Returns `false` if it was not queued.
  Future<bool> deleteTask(String id) async {
    if (!_box.containsKey(id)) return false;
    await _box.delete(id);
    _emitQueueChanged();
    return true;
  }

  /// Removes every task.
  Future<void> clearQueue() async {
    await _box.clear();
    _emitQueueChanged();
  }

  /// Stops delivery and closes the streams. A pass that is running stops
  /// after its current task. The Hive box stays open.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _queueController.close();
    _failedController.close();
  }
}
