// Regression tests for the 26 behaviour probes of the 1.0.0 audit
// (P01-P25 plus P08b). Each one failed (or was unobservable) on 1.0.0.
import 'dart:async';
import 'dart:io';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart' show Hive;

class Post {
  final int id;
  final String title;
  Post(this.id, this.title);
  factory Post.fromJson(Map<String, dynamic> j) =>
      Post(j['id'] as int, j['title'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

/// The adapter a user would naturally write from the 1.0 README.
// ignore: deprecated_member_use_from_same_package
class NaivePostAdapter implements TypeAdapter<Post> {
  @override
  Post fromData(dynamic data) => Post.fromJson(data as Map<String, dynamic>);
  @override
  dynamic toData(Post value) => value.toJson();
}

Future<HiveCacheStorage> openHive(String box) async {
  final hs = HiveCacheStorage(boxName: box);
  await hs.init(initHive: false);
  return hs;
}

Future<HiveCacheStorage> restartHive(String box) async {
  await Hive.close();
  return openHive(box);
}

void main() {
  late Directory tmp;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('cn_regression');
    Hive.init(tmp.path);
  });
  setUp(() => NetworkStatus.setMockStatus(true));
  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('P01 SimpleEncryptor round-trips Arabic text', () {
    // ignore: deprecated_member_use_from_same_package
    final e = SimpleEncryptor('my-secret');
    const s = 'مرحبا بالعالم';
    expect(e.decrypt(e.encrypt(s)), s);
  });

  test('P02 SecureCacheStorage(SimpleEncryptor) keeps Arabic data', () async {
    final st = SecureCacheStorage(
      MemoryCacheStorage(),
      // ignore: deprecated_member_use_from_same_package
      encryptor: SimpleEncryptor('k3y'),
    );
    final cache = CacheNexusManager(persistentStorage: st);
    await cache.set(key: 'name', data: 'عبد الفتاح');
    expect((await st.read('name'))?.data, 'عبد الفتاح');
  });

  test('P03 Hive accepts an Arabic key, also after a restart', () async {
    var hs = await openHive('p03');
    await CacheNexusManager(
      persistentStorage: hs,
    ).get<String>(key: 'مدارس', fetcher: () async => 'x');
    hs = await restartHive('p03');
    var fetches = 0;
    final v = await CacheNexusManager(persistentStorage: hs).get<String>(
      key: 'مدارس',
      fetcher: () async {
        fetches++;
        return 'y';
      },
    );
    expect(v, 'x');
    expect(fetches, 0);
  });

  test('P04 Hive accepts a long (URL-like) key', () async {
    final hs = await openHive('p04');
    final cache = CacheNexusManager(
      persistentStorage: hs,
      context: const CacheContext(userId: 'u1'),
    );
    final key =
        'GET https://api.example.com/v1/posts?'
        '${List.generate(40, (i) => 'f$i=v$i').join('&')}';
    expect(key.length, greaterThan(255));
    expect(await cache.get<String>(key: key, fetcher: () async => 'x'), 'x');
    expect(
      await cache.get<String>(
        key: key,
        fetcher: () async => 'refetched',
        policy: CachePolicy.cacheOnly,
      ),
      'x',
    );
  });

  test('P05 cold start: Map<String, dynamic> is served from disk', () async {
    final hs = await openHive('p05');
    var fetches = 0;
    Future<Map<String, dynamic>> f() async {
      fetches++;
      return {
        'id': 1,
        'nested': {'a': 1},
      };
    }

    await CacheNexusManager(persistentStorage: hs).get<Map<String, dynamic>>(
      key: 'm',
      fetcher: f,
      ttl: const Duration(hours: 1),
    );
    final again = await CacheNexusManager(
      persistentStorage: await restartHive('p05'),
    ).get<Map<String, dynamic>>(key: 'm', fetcher: f);
    expect(fetches, 1);
    expect(again['nested'], isA<Map<String, dynamic>>());
  });

  test('P06 cold start: List<String> is served from disk', () async {
    final hs = await openHive('p06');
    var fetches = 0;
    Future<List<String>> f() async {
      fetches++;
      return ['a', 'b'];
    }

    await CacheNexusManager(
      persistentStorage: hs,
    ).get<List<String>>(key: 'l', fetcher: f);
    final v = await CacheNexusManager(
      persistentStorage: await restartHive('p06'),
    ).get<List<String>>(key: 'l', fetcher: f);
    expect(fetches, 1);
    expect(v, ['a', 'b']);
  });

  test('P07 naive adapter: second get (memory hit) works', () async {
    final cache = CacheNexusManager();
    cache.registerAdapter<Post>(NaivePostAdapter());
    await cache.get<Post>(key: 'p', fetcher: () async => Post(1, 'a'));
    final p = await cache.get<Post>(
      key: 'p',
      fetcher: () async => Post(9, 'z'),
    );
    expect(p.id, 1);
  });

  test('P08 naive adapter with Hive (new manager, same box)', () async {
    final hs = await openHive('p08');
    final c1 = CacheNexusManager(persistentStorage: hs)
      ..registerAdapter<Post>(NaivePostAdapter());
    await c1.get<Post>(key: 'p', fetcher: () async => Post(1, 'a'));
    final c2 = CacheNexusManager(persistentStorage: hs)
      ..registerAdapter<Post>(NaivePostAdapter());
    final p = await c2.get<Post>(key: 'p', fetcher: () async => Post(9, 'z'));
    expect(p.title, 'a');
  });

  test(
    'P08b naive adapter after a real cold start (box closed + reopened)',
    () async {
      final hs = await openHive('p08b');
      final c1 = CacheNexusManager(persistentStorage: hs)
        ..registerAdapter<Post>(NaivePostAdapter());
      await c1.get<Post>(key: 'p', fetcher: () async => Post(1, 'a'));
      final c2 = CacheNexusManager(persistentStorage: await restartHive('p08b'))
        ..registerAdapter<Post>(NaivePostAdapter());
      final p = await c2.get<Post>(key: 'p', fetcher: () async => Post(9, 'z'));
      expect(p.title, 'a');
    },
  );

  test(
    'P09 staleWhileRevalidate returns the expired value immediately',
    () async {
      final cache = CacheNexusManager();
      await cache.set(
        key: 's',
        data: 'old',
        ttl: const Duration(milliseconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final c = Completer<String>();
      final v = await cache.get<String>(
        key: 's',
        fetcher: () => c.future,
        policy: CachePolicy.staleWhileRevalidate,
      );
      expect(v, 'old');
      c.complete('new');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        await cache.get<String>(
          key: 's',
          fetcher: () async => 'x',
          policy: CachePolicy.cacheOnly,
        ),
        'new',
      );
    },
  );

  test('P10 one fetch => one stream emission', () async {
    final cache = CacheNexusManager();
    final got = <String?>[];
    final sub = cache.watch<String>('w').listen(got.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    got.clear();
    await cache.get<String>(
      key: 'w',
      fetcher: () async => 'v1',
      policy: CachePolicy.networkOnly,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(got, ['v1']);
  });

  test('P11 a second watcher does not re-emit to the first', () async {
    final cache = CacheNexusManager();
    await cache.set(key: 'x', data: 'v');
    final a = <String?>[];
    final b = <String?>[];
    final s1 = cache.watch<String>('x').listen(a.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final s2 = cache.watch<String>('x').listen(b.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await s1.cancel();
    await s2.cancel();
    expect(a, ['v']);
    expect(b, ['v']);
  });

  test('P12 clear() and invalidateByContext() notify watchers', () async {
    final cache = CacheNexusManager(context: const CacheContext(userId: 'u1'));
    await cache.set(key: 'k', data: 'v');
    final seen = <String?>[];
    final sub = cache.watch<String>('k').listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    seen.clear();
    await cache.clear();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(seen, [null]);

    await cache.set(key: 'k', data: 'v2');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    seen.clear();
    await cache.invalidateByContext(const CacheContext(userId: 'u1'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(seen, [null]);
  });

  test(
    'P13 networkFirst failure with empty cache surfaces the network error',
    () async {
      final cache = CacheNexusManager();
      await expectLater(
        cache.get<String>(
          key: 'n',
          fetcher: () async => throw const SocketException('timeout'),
          policy: CachePolicy.networkFirst,
        ),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test('P14 a cached null value is a cache hit', () async {
    final cache = CacheNexusManager();
    var fetches = 0;
    for (var i = 0; i < 3; i++) {
      await cache.get<String?>(
        key: 'nul',
        fetcher: () async {
          fetches++;
          return null;
        },
      );
    }
    expect(fetches, 1);
  });

  test('P15 dispose() during SWR revalidation does not throw', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    await cache.set(key: 'd', data: 'v', ttl: const Duration(hours: 1));
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final c = Completer<String>();
      await cache.get<String>(
        key: 'd',
        fetcher: () => c.future,
        policy: CachePolicy.staleWhileRevalidate,
      );
      cache.dispose();
      c.complete('new');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }, (e, s) => errors.add(e));
    expect(errors, isEmpty);
  });

  test('P16 an executor that throws does not block the queue', () async {
    final done = <String>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: 'p16',
      executor: (t) async {
        if (t.id == 'bad') throw Exception('500 from server');
        done.add(t.id);
        return true;
      },
    );
    await engine.init();
    await engine.enqueue(
      SyncTask(
        key: 'k',
        id: 'bad',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime.now(),
      ),
    );
    await engine.enqueue(
      SyncTask(
        key: 'k',
        id: 'good',
        endpoint: '/b',
        method: 'POST',
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
      ),
    );
    expect(done, ['good']);
    final bad = engine.pendingTasks.single;
    expect(bad.id, 'bad');
    expect(bad.retryCount, greaterThan(0));
    expect(bad.lastError, contains('500 from server'));
    engine.dispose();
  });

  test('P17 a task enqueued while the queue is processing is sent', () async {
    final done = <String>[];
    final gate = Completer<void>();
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: 'p17',
      executor: (t) async {
        if (t.id == 'slow') await gate.future;
        done.add(t.id);
        return true;
      },
    );
    await engine.init();
    final f1 = engine.enqueue(
      SyncTask(
        key: 'k',
        id: 'slow',
        endpoint: '/a',
        method: 'POST',
        createdAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await engine.enqueue(
      SyncTask(
        key: 'k',
        id: 'late',
        endpoint: '/b',
        method: 'POST',
        createdAt: DateTime.now(),
      ),
    );
    gate.complete();
    await f1;
    expect(done, ['slow', 'late']);
    expect(engine.pendingTasks, isEmpty);
    engine.dispose();
  });

  test(
    'P18 tasks that failed maxRetries times are surfaced and retryable',
    () async {
      var serverUp = false;
      final engine = SyncEngine(
        initHive: false,
        queueBoxName: 'p18',
        executor: (t) async => serverUp,
      );
      await engine.init();
      final failed = <SyncTask>[];
      final sub = engine.onTaskFailed.listen(failed.add);
      await engine.enqueue(
        SyncTask(
          key: 'k',
          id: 't',
          endpoint: '/a',
          method: 'POST',
          createdAt: DateTime.now(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await engine.processQueue();
      }
      expect(engine.failedTasks.single.retryCount, 3);
      expect(failed.single.id, 't');

      serverUp = true;
      expect(await engine.retryFailed(), 1);
      expect(engine.pendingTasks, isEmpty);
      await sub.cancel();
      engine.dispose();
    },
  );

  testWidgets(
    'P19 CacheNexusOverlay inside MaterialApp.builder opens the panel',
    (tester) async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              CacheNexusOverlay(manager: cache, child: child!),
          home: const Text('home'),
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cache Nexus Dev Panel'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );

  test('P20 NetworkStatus survives dispose()', () {
    NetworkStatus.dispose();
    NetworkStatus.setMockStatus(false);
    NetworkStatus.setMockStatus(true);
  });

  test('P21 CacheContext prefixes cannot collide across users', () {
    const a = CacheContext(userId: 'ali', role: 'admin');
    const b = CacheContext(userId: 'ali_admin');
    expect(a.cacheKeyPrefix, isNot(b.cacheKeyPrefix));
    expect(b.cacheKeyPrefix.startsWith(a.userKeyPrefix), isFalse);
  });

  test('P22 SimpleCompressor actually compresses', () {
    final s = 'a' * 1000;
    final out = const SimpleCompressor().compress(s);
    expect(out.length, lessThan(s.length));
    expect(const SimpleCompressor().decompress(out), s);
  });

  test(
    'P23 offline cold start: networkFirst List<String> served from Hive',
    () async {
      final hs = await openHive('p23');
      await CacheNexusManager(
        persistentStorage: hs,
      ).get<List<String>>(key: 'l', fetcher: () async => ['a', 'b']);
      final reopened = await restartHive('p23');
      NetworkStatus.setMockStatus(false);
      final v = await CacheNexusManager(persistentStorage: reopened)
          .get<List<String>>(
            key: 'l',
            fetcher: () async => throw const SocketException('offline'),
            policy: CachePolicy.networkFirst,
          );
      expect(v, ['a', 'b']);
    },
  );

  test('P24 get() in dev mode when dispose() happens mid-fetch', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    final c = Completer<String>();
    final f = cache.get<String>(key: 'z', fetcher: () => c.future);
    cache.dispose();
    c.complete('ok');
    expect(await f, 'ok');
  });

  test('P25 offline-todo pattern: todos survive an app restart', () async {
    var hs = await openHive('p25');
    CacheNexusManager build(HiveCacheStorage s) =>
        CacheNexusManager(persistentStorage: s)..registerAdapter<Post>(
          CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
        );
    var cache = build(hs);
    Future<List<Post>> getTodos() => cache.get<List<Post>>(
      key: 'todos',
      fetcher: () async => <Post>[],
      ttl: const Duration(hours: 24),
    );
    await cache.set<List<Post>>(
      key: 'todos',
      data: [...await getTodos(), Post(1, 'buy milk')],
    );
    await cache.set<List<Post>>(
      key: 'todos',
      data: [...await getTodos(), Post(2, 'call mom')],
    );
    hs = await restartHive('p25');
    cache = build(hs);
    final after = await getTodos();
    expect(after.map((p) => p.title), ['buy milk', 'call mom']);
  });

  test('P25b without an adapter the miss is explained, not silent', () async {
    final hs = await openHive('p25b');
    await CacheNexusManager(
      persistentStorage: hs,
    ).set<List<Post>>(key: 'todos', data: [Post(1, 'a')]);
    final reopened = await restartHive('p25b');
    final cache = CacheNexusManager(
      persistentStorage: reopened,
      mode: CacheNexusMode.dev,
    );
    final errors = <CacheEvent>[];
    final sub = cache.events
        .where((e) => e.type == CacheEventType.error)
        .listen(errors.add);
    await expectLater(
      cache.get<List<Post>>(
        key: 'todos',
        fetcher: () async => <Post>[],
        policy: CachePolicy.cacheOnly,
      ),
      throwsA(
        isA<CacheDecodeException>().having(
          (e) => e.toString(),
          'message',
          contains('registerAdapter'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(errors, isNotEmpty);
    await sub.cancel();
  });
}
