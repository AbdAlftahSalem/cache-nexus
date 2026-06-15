import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late SmartCacheManager cacheManager;
  late HiveCacheStorage persistentStorage;
  late SyncEngine syncEngine;
  final tempDir = Directory.systemTemp.createTempSync();

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
    NetworkStatus.setMockStatus(true);
    persistentStorage = HiveCacheStorage(boxName: 'test_cache');
    await persistentStorage.init(initHive: false);
    await persistentStorage.clear();

    syncEngine = SyncEngine(
      executor: (task) async {
        if (task.endpoint == 'fail') return false;
        return true;
      },
      queueBoxName: 'test_sync_queue',
      initHive: false,
    );
    await syncEngine.init();

    cacheManager = SmartCacheManager(
      persistentStorage: persistentStorage,
      syncEngine: syncEngine,
      mode: SmartCacheMode.dev,
    );
  });

  group('Offline Engine - Persistence', () {
    test('Data survives manager recreation (Hive recovery)', () async {
      const key = 'persistent_data';
      const data = {'id': 1, 'value': 'important'};

      await cacheManager.set(key: key, data: data);

      // Simulate app restart by creating a new manager with same storage
      final newManager = SmartCacheManager(
        persistentStorage: persistentStorage,
      );

      final recovered = await newManager.get<Map>(
        key: key,
        fetcher: () async => throw Exception('Should not reach network'),
        policy: CachePolicy.cacheOnly,
      );

      expect(recovered, equals(data));
      expect(recovered['id'], 1);
    });

    test('Expired data in persistent storage is correctly invalidated', () async {
      const key = 'soon_to_expire';
      await cacheManager.set(
        key: key,
        data: 'old',
        ttl: const Duration(milliseconds: 50),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Should fail to get from cache only
      expect(
        () => cacheManager.get<String>(
          key: key,
          fetcher: () async => throw Exception('Net error'),
          policy: CachePolicy.cacheOnly,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Corrupted data in persistent storage is handled gracefully', () async {
      // Manually put corrupted data into Hive
      await persistentStorage.box.put('corrupt', 'not-a-json-map');

      final result = await cacheManager.get<String>(
        key: 'corrupt',
        fetcher: () async => 'fresh_data',
        policy: CachePolicy.cacheFirst,
      );

      expect(result, equals('fresh_data'));
    });
  });

  group('Offline Engine - Connectivity & Fallback', () {
    test('NetworkFirst falls back to persistent cache when offline', () async {
      const key = 'fallback_test';
      await cacheManager.set(key: key, data: 'cached_version');

      NetworkStatus.setMockStatus(false);

      final result = await cacheManager.get<String>(
        key: key,
        fetcher: () async => 'network_version',
        policy: CachePolicy.networkFirst,
      );

      expect(result, equals('cached_version'));
    });

    test('NetworkFirst throws when offline and cache is missing', () async {
      NetworkStatus.setMockStatus(false);

      expect(
        () => cacheManager.get<String>(
          key: 'missing_everywhere',
          fetcher: () async => 'data',
          policy: CachePolicy.networkFirst,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Offline Engine - Sync Queue', () {
    test('Sync tasks are queued and retried', () async {
      final task = SyncTask(
        id: 't1',
        key: 'k1',
        endpoint: 'success',
        method: 'POST',
        createdAt: DateTime.now(),
      );

      // Initially offline so it stays in queue
      NetworkStatus.setMockStatus(false);
      await cacheManager.enqueueSyncTask(task);
      
      // Should still be in box (we check box directly for "good content")
      final box = await Hive.openBox('test_sync_queue');
      expect(box.containsKey('t1'), isTrue);

      // Go online
      NetworkStatus.setMockStatus(true);
      await syncEngine.processQueue();
      
      expect(box.containsKey('t1'), isFalse);
    });

    test('Sync tasks respect max retries', () async {
      final task = SyncTask(
        id: 'fail_task',
        key: 'k2',
        endpoint: 'fail',
        method: 'PUT',
        createdAt: DateTime.now(),
      );

      // Start offline so it just sits in queue with 0 retries
      NetworkStatus.setMockStatus(false);
      await cacheManager.enqueueSyncTask(task);
      
      final box = await Hive.openBox('test_sync_queue');
      expect(box.get('fail_task')['retryCount'], 0);

      // Go online and process
      NetworkStatus.setMockStatus(true);
      
      await syncEngine.processQueue(); // Try 1: fails, retryCount -> 1
      expect(box.get('fail_task')['retryCount'], 1);

      await syncEngine.processQueue(); // Try 2: fails, retryCount -> 2
      expect(box.get('fail_task')['retryCount'], 2);

      await syncEngine.processQueue(); // Try 3: fails, retryCount -> 3, DELETED
      expect(box.containsKey('fail_task'), isFalse);
    });
   group('Offline Engine - Multi-Layer Storage', () {
    test('Set updates both layers', () async {
      await cacheManager.set(key: 'multi', data: 'val');
      
      final mem = await cacheManager.memoryStorage.read('multi');
      final pers = await persistentStorage.read('multi');
      
      expect(mem?.data, 'val');
      expect(pers?.data, 'val');
    });

    test('Delete removes from both layers', () async {
      await cacheManager.set(key: 'multi', data: 'val');
      await cacheManager.delete('multi');
      
      final mem = await cacheManager.memoryStorage.read('multi');
      final pers = await persistentStorage.read('multi');
      
      expect(mem, isNull);
      expect(pers, isNull);
    });
  });
});
}
