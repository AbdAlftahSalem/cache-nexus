// Real disk restarts: every test writes through Hive, closes it (as an app
// kill would), reopens it and reads with a brand-new manager.
import 'dart:io';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart' show Hive;

class Todo {
  Todo(this.id, this.title, {this.done = false});
  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
    j['id'] as int,
    j['title'] as String,
    done: j['done'] as bool? ?? false,
  );
  final int id;
  final String title;
  final bool done;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}

CacheNexusManager managerFor(CacheStorage storage, {CacheContext? context}) =>
    CacheNexusManager(persistentStorage: storage, context: context)
      ..registerAdapter<Todo>(
        CacheAdapter.json(fromJson: Todo.fromJson, toJson: (t) => t.toJson()),
      );

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cn_restart');
    Hive.init(tmp.path);
    NetworkStatus.setMockStatus(true);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Future<HiveCacheStorage> open([String box = 'cache']) async {
    final s = HiveCacheStorage(boxName: box);
    await s.init(initHive: false);
    return s;
  }

  Future<HiveCacheStorage> restart([String box = 'cache']) async {
    await Hive.close();
    return open(box);
  }

  Never offline() => throw const SocketException('offline');

  test('offline-todo: list survives a restart while offline', () async {
    var cache = managerFor(await open());
    await cache.set<List<Todo>>(
      key: 'todos',
      data: [Todo(1, 'اشتري حليب'), Todo(2, 'call mom', done: true)],
    );

    final storage = await restart();
    NetworkStatus.setMockStatus(false);
    cache = managerFor(storage);
    for (final policy in [
      CachePolicy.cacheFirst,
      CachePolicy.networkFirst,
      CachePolicy.cacheOnly,
      CachePolicy.staleWhileRevalidate,
    ]) {
      final todos = await cache.get<List<Todo>>(
        key: 'todos',
        fetcher: () async => offline(),
        policy: policy,
      );
      expect(todos.map((t) => t.title), [
        'اشتري حليب',
        'call mom',
      ], reason: '$policy');
      expect(todos.last.done, isTrue);
    }
  });

  test('typed collections and scalars survive a restart', () async {
    final cache = managerFor(await open());
    await cache.set<Map<String, Todo>>(key: 'byId', data: {'1': Todo(1, 'a')});
    await cache.set<List<int>>(key: 'ints', data: [1, 2, 3]);
    await cache.set<List<double>>(key: 'doubles', data: [1.5, 2]);
    await cache.set<Map<String, int>>(key: 'counts', data: {'a': 1});
    await cache.set<Set<String>>(key: 'set', data: {'x', 'y'});
    await cache.set<DateTime>(key: 'when', data: DateTime(2026, 10, 30, 8));
    await cache.set<double>(key: 'price', data: 3);
    await cache.set<Todo?>(key: 'maybe', data: null);
    await cache.set<List<Map<String, dynamic>>>(
      key: 'rows',
      data: [
        {'a': 1},
      ],
    );

    final c2 = managerFor(await restart());
    Future<T> read<T>(String key) => c2.get<T>(
      key: key,
      fetcher: () async => offline(),
      policy: CachePolicy.cacheOnly,
    );
    expect((await read<Map<String, Todo>>('byId'))['1']!.title, 'a');
    expect(await read<List<int>>('ints'), [1, 2, 3]);
    expect(await read<List<double>>('doubles'), [1.5, 2.0]);
    expect(await read<Map<String, int>>('counts'), {'a': 1});
    expect(await read<Set<String>>('set'), {'x', 'y'});
    expect(await read<DateTime>('when'), DateTime(2026, 10, 30, 8));
    expect(await read<double>('price'), 3.0);
    expect(await read<Todo?>('maybe'), isNull);
    expect((await read<List<Map<String, dynamic>>>('rows')).single['a'], 1);
  });

  test(
    'long and non-Latin keys survive a restart and prefix deletes',
    () async {
      final storage = await open();
      final cache = managerFor(
        storage,
        context: const CacheContext(userId: 'عبد'),
      );
      final longKey = 'مدرسة-' * 60; // 360 chars, ~660 UTF-8 bytes
      await cache.set<String>(key: longKey, data: 'v');
      await cache.set<String>(key: 'short', data: 's');

      final c2 = managerFor(
        await restart(),
        context: const CacheContext(userId: 'عبد'),
      );
      expect(
        await c2.get<String>(key: longKey, fetcher: () async => offline()),
        'v',
      );

      await c2.invalidateByContext(const CacheContext(userId: 'عبد'));
      expect(
        await c2.get<String?>(
          key: longKey,
          fetcher: () async => null,
          policy: CachePolicy.cacheOnly,
        ),
        isNull,
      );
      expect(
        await c2.get<String?>(
          key: 'short',
          fetcher: () async => null,
          policy: CachePolicy.cacheOnly,
        ),
        isNull,
      );
    },
  );

  test('hashed keys never return a different key\'s value', () {
    final a = HiveCacheStorage.storageKeyFor('x' * 300);
    final b = HiveCacheStorage.storageKeyFor('y' * 300);
    expect(a, isNot(b));
    expect(a.length, lessThanOrEqualTo(255));
    expect(HiveCacheStorage.storageKeyFor('short'), 'short');
  });

  test('AES-encrypted Hive cache survives a restart (Arabic data)', () async {
    final key = AesGcmEncryptor.generateKey();
    SecureCacheStorage secure(HiveCacheStorage s) => SecureCacheStorage(
      s,
      encryptor: AesGcmEncryptor(key),
      compressor: const GZipCompressor(),
    );
    final cache = managerFor(secure(await open()));
    await cache.set<List<Todo>>(key: 'todos', data: [Todo(1, 'عبد الفتاح')]);

    final raw = (await open()).box.get('todos').toString();
    expect(raw, isNot(contains('عبد')));

    final c2 = managerFor(secure(await restart()));
    final todos = await c2.get<List<Todo>>(
      key: 'todos',
      fetcher: () async => offline(),
    );
    expect(todos.single.title, 'عبد الفتاح');
  });

  test('a box written by hive 2.2.3 (cache_nexus 1.0) is readable', () async {
    for (final name in ['legacy_cache.hive', 'legacy_queue.hive']) {
      await File('test/fixtures/hive_v2/$name').copy('${tmp.path}/$name');
    }
    final storage = await open('legacy_cache');
    final cache = managerFor(storage);
    final todos = await cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () async => offline(),
      policy: CachePolicy.cacheOnly,
    );
    expect(todos.first.title, 'اشتري حليب');
    expect(
      await cache.get<List<String>>(
        key: 'names',
        fetcher: () async => offline(),
      ),
      ['a', 'b', 'عبد'],
    );
    final profile = await cache.get<Map<String, dynamic>>(
      key: 'profile',
      fetcher: () async => offline(),
    );
    expect(profile['name'], 'عبد الفتاح');

    // A 1.0 user-scoped key ("u1_settings") is found and migrated.
    final scoped = managerFor(
      storage,
      context: const CacheContext(userId: 'u1'),
    );
    final settings = await scoped.get<Map<String, dynamic>>(
      key: 'settings',
      fetcher: () async => offline(),
    );
    expect(settings['theme'], 'dark');
    expect(storage.box.containsKey('u1_settings'), isFalse);
    expect(storage.box.containsKey('u2:u1|r|settings'), isTrue);

    // The 1.0 sync queue is picked up too.
    final sent = <String>[];
    final engine = SyncEngine(
      initHive: false,
      queueBoxName: 'legacy_queue',
      executor: (t) async {
        sent.add('${t.method} ${t.endpoint} ${t.body}');
        return true;
      },
    );
    await engine.init();
    await engine.processQueue();
    expect(sent, ['POST /todos {title: buy milk}']);
    engine.dispose();
  });

  test('sync queue survives a restart and drains when back online', () async {
    NetworkStatus.setMockStatus(false);
    var engine = SyncEngine(
      initHive: false,
      queueBoxName: 'q',
      executor: (t) async => true,
    );
    await engine.init();
    await engine.enqueue(
      SyncTask(
        id: 'a',
        key: 'todos',
        endpoint: '/todos',
        method: 'POST',
        body: Todo(1, 'x'),
        createdAt: DateTime.now(),
      ),
    );
    engine.dispose();
    await Hive.close();

    final sent = <dynamic>[];
    engine = SyncEngine(
      initHive: false,
      queueBoxName: 'q',
      executor: (t) async {
        sent.add(t.body);
        return true;
      },
    );
    await engine.init();
    expect(engine.pendingTasks.single.id, 'a');
    NetworkStatus.setMockStatus(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent.single, {'id': 1, 'title': 'x', 'done': false});
    expect(engine.pendingTasks, isEmpty);
    engine.dispose();
  });

  test('HiveCacheStorage guards', () async {
    final s = HiveCacheStorage(boxName: 'g');
    expect(s.isInitialized, isFalse);
    expect(() => s.box, throwsException);
    await s.init(initHive: false);
    expect(s.isInitialized, isTrue);
    await s.box.put('broken', 'not a map');
    expect(await s.read('broken'), isNull);
    expect(s.box.containsKey('broken'), isFalse);
    await s.write(
      'k',
      CacheEntry<String>(data: 'v', createdAt: DateTime.now()),
    );
    await s.clear();
    expect(await s.read('k'), isNull);
    await s.close();
    expect(s.isInitialized, isFalse);
  });
}
