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

  test('task dropped after max retries', () async {
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
    expect(box.containsKey('task_4'), isFalse);
  });
}
