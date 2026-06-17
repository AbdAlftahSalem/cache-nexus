import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_cache/smart_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SyncEngine syncEngine;
  late String boxName;
  int executedCount = 0;
  bool shouldSucceed = true;
  final tempDir = Directory.systemTemp.createTempSync('sync_test_');

  setUpAll(() async {
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    executedCount = 0;
    shouldSucceed = true;
    boxName = 'test_sync_${DateTime.now().millisecondsSinceEpoch}';
    NetworkStatus.setMockStatus(true);
    syncEngine = SyncEngine(
      executor: (task) async {
        executedCount++;
        return shouldSucceed;
      },
      queueBoxName: boxName,
      initHive: false,
    );
    await syncEngine.init();
  });

  tearDown(() async {
    syncEngine.dispose();
  });

  test('task queued and executed when online', () async {
    NetworkStatus.setMockStatus(true);

    final task = SyncTask(
      id: 'task_1',
      key: 'k1',
      endpoint: 'https://example.com/api',
      method: 'POST',
      body: {'data': 'test'},
      createdAt: DateTime.now(),
    );

    await syncEngine.enqueue(task);

    expect(executedCount, 1);

    final box = await Hive.openBox(boxName);
    expect(box.containsKey('task_1'), isFalse);
  });

  test('task stays queued when offline', () async {
    NetworkStatus.setMockStatus(false);

    final task = SyncTask(
      id: 'task_2',
      key: 'k2',
      endpoint: 'https://example.com/api',
      method: 'POST',
      body: {'data': 'test'},
      createdAt: DateTime.now(),
    );

    await syncEngine.enqueue(task);

    expect(executedCount, 0);

    final box = await Hive.openBox(boxName);
    expect(box.containsKey('task_2'), isTrue);
  });

  test('task retried on failure', () async {
    NetworkStatus.setMockStatus(true);
    shouldSucceed = false;

    final task = SyncTask(
      id: 'task_3',
      key: 'k3',
      endpoint: 'https://example.com/api',
      method: 'POST',
      body: {'data': 'test'},
      createdAt: DateTime.now(),
    );

    await syncEngine.enqueue(task);

    final box = await Hive.openBox(boxName);
    expect(box.containsKey('task_3'), isTrue);
    expect(box.get('task_3')['retryCount'], 1);
  });

  test('failed task stays in queue after max retries', () async {
    NetworkStatus.setMockStatus(true);
    shouldSucceed = false;

    final task = SyncTask(
      id: 'task_4',
      key: 'k4',
      endpoint: 'https://example.com/api',
      method: 'POST',
      body: {'data': 'test'},
      createdAt: DateTime.now(),
    );

    await syncEngine.enqueue(task);

    final box = await Hive.openBox(boxName);
    expect(box.get('task_4')['retryCount'], 1);

    await syncEngine.processQueue();
    expect(box.get('task_4')['retryCount'], 2);

    await syncEngine.processQueue();
    expect(box.get('task_4')['retryCount'], 3);

    await syncEngine.processQueue();
    expect(box.containsKey('task_4'), isTrue);
    expect(box.get('task_4')['retryCount'], 3);
  });

  test('task auto-processes when going online', () async {
    NetworkStatus.setMockStatus(false);

    final task = SyncTask(
      id: 'task_5',
      key: 'k5',
      endpoint: 'https://example.com/api',
      method: 'POST',
      body: {'data': 'test'},
      createdAt: DateTime.now(),
    );

    await syncEngine.enqueue(task);

    final box = await Hive.openBox(boxName);
    expect(box.containsKey('task_5'), isTrue);
    expect(executedCount, 0);

    NetworkStatus.setMockStatus(true);
    await Future.delayed(const Duration(milliseconds: 100));

    expect(executedCount, 1);
    expect(box.containsKey('task_5'), isFalse);
  });

  group('pendingTasks', () {
    test('returns empty list initially', () async {
      expect(syncEngine.pendingTasks, isEmpty);
    });

    test('returns tasks after enqueue', () async {
      NetworkStatus.setMockStatus(false);

      final task = SyncTask(
        id: 'pt_1',
        key: 'k1',
        endpoint: 'https://example.com/api',
        method: 'POST',
        body: {'data': 'test'},
        createdAt: DateTime.now(),
      );

      await syncEngine.enqueue(task);

      final pending = syncEngine.pendingTasks;
      expect(pending.length, 1);
      expect(pending.first.id, 'pt_1');
    });

    test('tasks sorted by createdAt ascending', () async {
      NetworkStatus.setMockStatus(false);

      final t1 = SyncTask(
        id: 'pt_2',
        key: 'k1',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime(2025, 1, 1, 10, 0, 0),
      );
      final t2 = SyncTask(
        id: 'pt_3',
        key: 'k2',
        endpoint: '/b',
        method: 'POST',
        createdAt: DateTime(2025, 1, 1, 9, 0, 0),
      );

      await syncEngine.enqueue(t1);
      await syncEngine.enqueue(t2);

      final pending = syncEngine.pendingTasks;
      expect(pending.first.id, 'pt_3');
      expect(pending.last.id, 'pt_2');
    });
  });

  group('onQueueChanged', () {
    test('emits after enqueue', () async {
      NetworkStatus.setMockStatus(false);

      final emitted = <List<SyncTask>>[];
      final sub = syncEngine.onQueueChanged.listen(emitted.add);

      final task = SyncTask(
        id: 'stream_1',
        key: 'k1',
        endpoint: '/test',
        method: 'POST',
        createdAt: DateTime.now(),
      );

      await syncEngine.enqueue(task);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last.any((t) => t.id == 'stream_1'), isTrue);

      await sub.cancel();
    });

    test('emits after deleteTask', () async {
      NetworkStatus.setMockStatus(false);

      final task = SyncTask(
        id: 'stream_2',
        key: 'k1',
        endpoint: '/test',
        method: 'POST',
        createdAt: DateTime.now(),
      );
      await syncEngine.enqueue(task);

      final emitted = <List<SyncTask>>[];
      final sub = syncEngine.onQueueChanged.listen(emitted.add);

      await syncEngine.deleteTask('stream_2');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last.any((t) => t.id == 'stream_2'), isFalse);

      await sub.cancel();
    });

    test('emits after clearQueue', () async {
      NetworkStatus.setMockStatus(false);

      final task = SyncTask(
        id: 'stream_3',
        key: 'k1',
        endpoint: '/test',
        method: 'POST',
        createdAt: DateTime.now(),
      );
      await syncEngine.enqueue(task);

      final emitted = <List<SyncTask>>[];
      final sub = syncEngine.onQueueChanged.listen(emitted.add);

      await syncEngine.clearQueue();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, isEmpty);

      await sub.cancel();
    });
  });

  group('deleteTask', () {
    test('removes specific task', () async {
      NetworkStatus.setMockStatus(false);

      final t1 = SyncTask(
        id: 'del_1',
        key: 'k1',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime.now(),
      );
      final t2 = SyncTask(
        id: 'del_2',
        key: 'k2',
        endpoint: '/b',
        method: 'DELETE',
        createdAt: DateTime.now(),
      );

      await syncEngine.enqueue(t1);
      await syncEngine.enqueue(t2);

      final result = await syncEngine.deleteTask('del_1');

      expect(result, isTrue);
      expect(syncEngine.pendingTasks.length, 1);
      expect(syncEngine.pendingTasks.first.id, 'del_2');
    });

    test('returns false for non-existent task', () async {
      final result = await syncEngine.deleteTask('nonexistent');
      expect(result, isFalse);
    });
  });

  group('clearQueue', () {
    test('removes all tasks', () async {
      NetworkStatus.setMockStatus(false);

      final t1 = SyncTask(
        id: 'clr_1',
        key: 'k1',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime.now(),
      );
      final t2 = SyncTask(
        id: 'clr_2',
        key: 'k2',
        endpoint: '/b',
        method: 'DELETE',
        createdAt: DateTime.now(),
      );

      await syncEngine.enqueue(t1);
      await syncEngine.enqueue(t2);

      expect(syncEngine.pendingTasks.length, 2);

      await syncEngine.clearQueue();

      expect(syncEngine.pendingTasks, isEmpty);
    });
  });

  group('queueLength', () {
    test('returns 0 initially', () async {
      expect(await syncEngine.queueLength, 0);
    });

    test('returns correct count after enqueue', () async {
      NetworkStatus.setMockStatus(false);

      await syncEngine.enqueue(SyncTask(
        id: 'ql_1',
        key: 'k1',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime.now(),
      ));
      await syncEngine.enqueue(SyncTask(
        id: 'ql_2',
        key: 'k2',
        endpoint: '/b',
        method: 'POST',
        createdAt: DateTime.now(),
      ));

      expect(await syncEngine.queueLength, 2);
    });
  });
}
