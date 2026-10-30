import 'dart:async';
import 'dart:io';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart' show Hive;

SyncTask task(String id, {int offsetMs = 0, Object? body}) => SyncTask(
  id: id,
  key: 'k',
  endpoint: '/$id',
  method: 'POST',
  body: body,
  createdAt: DateTime(2026, 1, 1).add(Duration(milliseconds: offsetMs)),
);

void main() {
  late Directory tmp;
  var boxSeq = 0;
  String box() => 'q${boxSeq++}';

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('cn_sync');
    Hive.init(tmp.path);
  });
  setUp(() => NetworkStatus.setMockStatus(true));
  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('a jammed queue drains when the server recovers', () async {
    var serverUp = false;
    final sent = <String>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      maxRetries: 5,
      executor: (t) async {
        if (!serverUp) throw const HttpException('503 Service Unavailable');
        sent.add(t.id);
        return true;
      },
    );
    await engine.init();
    for (var i = 0; i < 3; i++) {
      await engine.enqueue(task('t$i', offsetMs: i));
    }
    expect(sent, isEmpty);
    expect(
      engine.pendingTasks.map((t) => t.retryCount),
      everyElement(greaterThan(0)),
    );
    expect(engine.pendingTasks.first.lastError, contains('503'));

    serverUp = true;
    // Coming back online triggers delivery.
    NetworkStatus.setMockStatus(false);
    NetworkStatus.setMockStatus(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, ['t0', 't1', 't2']);
    expect(engine.pendingTasks, isEmpty);
    engine.dispose();
  });

  test('exponential backoff retries automatically', () async {
    final attempts = <DateTime>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      retryDelay: const Duration(milliseconds: 40),
      maxRetryDelay: const Duration(milliseconds: 80),
      maxRetries: 4,
      executor: (t) async {
        attempts.add(DateTime.now());
        return attempts.length >= 3;
      },
    );
    await engine.init();
    await engine.enqueue(task('b'));
    expect(attempts, hasLength(1));
    final next = engine.pendingTasks.single.nextAttemptAt;
    expect(next, isNotNull);

    // Not due yet: an explicit pass skips it.
    await engine.processQueue();
    expect(attempts, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(attempts, hasLength(3));
    expect(engine.pendingTasks, isEmpty);
    final gap1 = attempts[1].difference(attempts[0]);
    final gap2 = attempts[2].difference(attempts[1]);
    expect(gap1.inMilliseconds, greaterThanOrEqualTo(35));
    expect(gap2.inMilliseconds, greaterThanOrEqualTo(70));
    engine.dispose();
  });

  test('failed tasks are parked, reported and retryable by id', () async {
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      maxRetries: 1,
      executor: (t) async => false,
    );
    await engine.init();
    final failed = <String>[];
    final sub = engine.onTaskFailed.listen((t) => failed.add(t.id));
    await engine.enqueue(task('a'));
    await engine.enqueue(task('b', offsetMs: 1));
    await Future<void>.delayed(Duration.zero);
    expect(failed, ['a', 'b']);
    expect(engine.failedTasks.map((t) => t.id), ['a', 'b']);
    expect(engine.failedTasks.first.lastError, 'executor returned false');
    // Parked tasks are not retried by ordinary passes.
    await engine.processQueue();
    expect(engine.failedTasks.first.retryCount, 1);

    expect(await engine.retryFailed(id: 'b'), 1);
    expect(engine.failedTasks.map((t) => t.id), ['a', 'b']);
    expect(await engine.retryFailed(id: 'nope'), 0);
    await sub.cancel();
    engine.dispose();
  });

  test('queue helpers and change notifications', () async {
    NetworkStatus.setMockStatus(false);
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      executor: (t) async => true,
    );
    expect(engine.isInitialized, isFalse);
    expect(engine.pendingTasks, isEmpty);
    expect(await engine.queueLength, 0);
    expect(() => engine.enqueue(task('x')), throwsStateError);
    await engine.processQueue(); // no-op before init
    await engine.init();
    expect(engine.isInitialized, isTrue);

    final changes = <int>[];
    final sub = engine.onQueueChanged.listen((l) => changes.add(l.length));
    await engine.enqueue(task('b', offsetMs: 5));
    await engine.enqueue(task('a'));
    expect(engine.pendingTasks.map((t) => t.id), ['a', 'b']);
    expect(await engine.queueLength, 2);
    expect(await engine.deleteTask('a'), isTrue);
    expect(await engine.deleteTask('a'), isFalse);
    await engine.clearQueue();
    await Future<void>.delayed(Duration.zero);
    expect(changes, [1, 2, 1, 0]);
    await sub.cancel();
    engine.dispose();
    engine.dispose(); // idempotent
  });

  test(
    'bodies with toJson are stored as JSON; unreadable rows skipped',
    () async {
      NetworkStatus.setMockStatus(false);
      final name = box();
      final engine = SyncEngine(
        initHive: false,
        queueBoxName: name,
        executor: (t) async => true,
      );
      await engine.init();
      await engine.enqueue(
        task(
          'a',
          body: {
            'when': DateTime(2026),
            'tags': {'x'},
          },
        ),
      );
      final b = await Hive.openBox<dynamic>(name);
      await b.put('junk', 'not a task');
      final t = engine.pendingTasks.single;
      expect(t.body, {
        'when': '2026-01-01T00:00:00.000',
        'tags': ['x'],
      });
      engine.dispose();
    },
  );

  test('an executor that deletes its own task does not resurrect it', () async {
    late SyncEngine engine;
    engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      executor: (t) async {
        await engine.deleteTask(t.id);
        return false;
      },
    );
    await engine.init();
    await engine.enqueue(task('self'));
    expect(engine.pendingTasks, isEmpty);
    engine.dispose();
  });

  test('dispose stops a running pass after the current task', () async {
    final gate = Completer<void>();
    final sent = <String>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      executor: (t) async {
        if (t.id == 'a') await gate.future;
        sent.add(t.id);
        return true;
      },
    );
    await engine.init();
    NetworkStatus.setMockStatus(false);
    await engine.enqueue(task('a'));
    await engine.enqueue(task('b', offsetMs: 1));
    NetworkStatus.setMockStatus(true);
    final run = engine.processQueue();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    engine.dispose();
    gate.complete();
    await run;
    expect(sent, ['a']);
  });

  test('SyncTask json round trip', () {
    final t = SyncTask(
      id: 'i',
      key: 'k',
      endpoint: '/e',
      method: 'PUT',
      body: {'a': 1},
      createdAt: DateTime(2026),
      retryCount: 2,
      nextAttemptAt: DateTime(2026, 2),
      lastError: 'boom',
    );
    final back = SyncTask.fromJson(t.toJson());
    expect(back.nextAttemptAt, DateTime(2026, 2));
    expect(back.lastError, 'boom');
    expect(back.retryCount, 2);
    expect(back.toString(), contains('boom'));
  });

  test('manager integration: enqueueSyncTask and dispose', () async {
    final noEngine = CacheNexusManager();
    expect(() => noEngine.enqueueSyncTask(task('x')), throwsException);

    final sent = <String>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: box(),
      executor: (t) async {
        sent.add(t.id);
        return true;
      },
    );
    await engine.init();
    final cache = CacheNexusManager(syncEngine: engine);
    await cache.enqueueSyncTask(task('m'));
    expect(sent, ['m']);
    cache.dispose();
    expect(cache.isDisposed, isTrue);
    await engine.processQueue(); // disposed: does nothing, does not throw
  });
}
