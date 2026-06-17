// ignore_for_file: strict_raw_type

import 'dart:async';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    test('should not be expired when ttl is null', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now(),
        ttl: null,
      );
      expect(entry.isExpired, isFalse);
    });

    test('should be expired when ttl is passed', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now().subtract(Duration(minutes: 10)),
        ttl: Duration(minutes: 5),
      );
      expect(entry.isExpired, isTrue);
    });

    test('should not be expired when ttl is not yet reached', () {
      final entry = CacheEntry(
        data: 'data',
        createdAt: DateTime.now().subtract(Duration(minutes: 2)),
        ttl: Duration(minutes: 5),
      );
      expect(entry.isExpired, isFalse);
    });
  });

  group('ReactiveEngine', () {
    late ReactiveEngine engine;

    setUp(() {
      engine = ReactiveEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('auto-closes controller when last listener drops', () async {
      final stream = engine.watch<String>('test_key');
      final sub = stream.listen((_) {});

      expect(engine.controllerCount, 1);

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(engine.controllerCount, 0);
    });

    test('no memory leak after 1000 watch/cancel cycles', () async {
      for (var i = 0; i < 1000; i++) {
        final sub = engine.watch<String>('key_$i').listen((_) {});
        await sub.cancel();
      }
      expect(engine.controllerCount, 0);
    });
  });

  group('CacheNexusManager', () {
    late CacheNexusManager cache;
    late MemoryCacheStorage storage;

    setUp(() {
      NetworkStatus.setMockStatus(true);
      storage = MemoryCacheStorage();
      cache = CacheNexusManager(memoryStorage: storage);
    });

    test('set and get should work correctly', () async {
      await cache.set(key: 'key1', data: 'value1');
      final result = await cache.get(
        key: 'key1',
        fetcher: () async => 'fetched',
      );
      expect(result, 'value1');
    });

    test('get should call fetcher on cache miss', () async {
      var fetchCount = 0;
      final result = await cache.get(
        key: 'missing',
        fetcher: () async {
          fetchCount++;
          return 'fetched';
        },
      );
      expect(result, 'fetched');
      expect(fetchCount, 1);
    });

    test('get should call fetcher and update cache when expired', () async {
      await cache.set(
        key: 'expired_key',
        data: 'old_value',
        ttl: Duration(milliseconds: 1),
      );

      // Wait for expiration
      await Future<void>.delayed(Duration(milliseconds: 10));

      var fetchCount = 0;
      final result = await cache.get(
        key: 'expired_key',
        fetcher: () async {
          fetchCount++;
          return 'new_value';
        },
      );

      expect(result, 'new_value');
      expect(fetchCount, 1);

      // Verify it's updated in storage
      final entry = await storage.read('expired_key');
      expect(entry?.data, 'new_value');
    });

    test('delete should remove item from cache', () async {
      await cache.set(key: 'key1', data: 'value1');
      await cache.delete('key1');

      var fetchCount = 0;
      final result = await cache.get(
        key: 'key1',
        fetcher: () async {
          fetchCount++;
          return 'fetched';
        },
      );
      expect(result, 'fetched');
      expect(fetchCount, 1);
    });

    test('clear should remove all items', () async {
      await cache.set(key: 'key1', data: 'value1');
      await cache.set(key: 'key2', data: 'value2');
      await cache.clear();

      final entry1 = await storage.read('key1');
      final entry2 = await storage.read('key2');

      expect(entry1, isNull);
      expect(entry2, isNull);
    });

    test(
      'get should return null if fetcher returns null and T is nullable',
      () async {
        final result = await cache.get<String?>(
          key: 'key',
          fetcher: () async => null,
        );
        expect(result, isNull);
      },
    );

    group('Phase 2: Cache Policies', () {
      test('cacheFirst: returns cache if available and not expired', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.cacheFirst,
        );
        expect(result, 'cached_value');
        expect(fetchCount, 0);
      });

      test('cacheFirst: fetches if cache is missing', () async {
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.cacheFirst,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });

      test('networkFirst: returns fetched data on success', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.networkFirst,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);

        // Verify cache updated
        final entry = await storage.read('key');
        expect(entry?.data, 'fetched_value');
      });

      test('networkFirst: falls back to cache on fetch error', () async {
        await cache.set(key: 'key', data: 'cached_value');
        final result = await cache.get<String>(
          key: 'key',
          fetcher: () async => throw Exception('Fetch failed'),
          policy: CachePolicy.networkFirst,
        );
        expect(result, 'cached_value');
      });

      test('cacheOnly: returns cache if exists', () async {
        await cache.set(key: 'key', data: 'cached_value');
        final result = await cache.get(
          key: 'key',
          fetcher: () async => 'fetched',
          policy: CachePolicy.cacheOnly,
        );
        expect(result, 'cached_value');
      });

      test('cacheOnly: throws exception if cache missing', () async {
        expect(
          () => cache.get(
            key: 'missing',
            fetcher: () async => 'fetched',
            policy: CachePolicy.cacheOnly,
          ),
          throwsException,
        );
      });

      test('networkOnly: always fetches', () async {
        await cache.set(key: 'key', data: 'cached_value');
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.networkOnly,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });
    });

    group('Phase 2: Request Deduplication', () {
      test('multiple concurrent calls return the same future', () async {
        var fetchCount = 0;
        final f1 = cache.get(
          key: 'key',
          fetcher: () async {
            await Future<void>.delayed(Duration(milliseconds: 50));
            fetchCount++;
            return 'fetched_value';
          },
        );
        final f2 = cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value_2';
          },
        );

        final results = await Future.wait([f1, f2]);
        expect(results[0], 'fetched_value');
        expect(results[1], 'fetched_value');
        expect(fetchCount, 1);
      });
    });

    group('Phase 2: Stale-While-Revalidate (SWR)', () {
      test(
        'returns cached data immediately and refreshes in background',
        () async {
          await cache.set(key: 'key', data: 'stale_value');

          var fetchCount = 0;
          final result = await cache.get(
            key: 'key',
            fetcher: () async {
              await Future<void>.delayed(Duration(milliseconds: 20));
              fetchCount++;
              return 'fresh_value';
            },
            policy: CachePolicy.staleWhileRevalidate,
          );

          expect(result, 'stale_value');
          expect(fetchCount, 0);

          // Wait for background refresh
          await Future<void>.delayed(Duration(milliseconds: 50));
          expect(fetchCount, 1);

          // Next call should get fresh data
          final nextResult = await cache.get(
            key: 'key',
            fetcher: () async => 'even_fresher',
            policy: CachePolicy.cacheFirst,
          );
          expect(nextResult, 'fresh_value');
        },
      );

      test('behaves like cacheFirst if cache is missing', () async {
        var fetchCount = 0;
        final result = await cache.get(
          key: 'key',
          fetcher: () async {
            fetchCount++;
            return 'fetched_value';
          },
          policy: CachePolicy.staleWhileRevalidate,
        );
        expect(result, 'fetched_value');
        expect(fetchCount, 1);
      });
    });

    group('Phase 7: Persistent Storage Type Mismatch Resilience', () {
      late CacheNexusManager cacheWithPersistent;
      late MemoryCacheStorage memStorage;
      late MemoryCacheStorage persistentStorage;

      setUp(() {
        NetworkStatus.setMockStatus(true);
        memStorage = MemoryCacheStorage();
        persistentStorage = MemoryCacheStorage();
        cacheWithPersistent = CacheNexusManager(
          memoryStorage: memStorage,
          persistentStorage: persistentStorage,
        );
      });

      test(
        'cacheFirst: falls through to fetcher when persistent data type mismatches',
        () async {
          // Simulate a deserialized Map in persistent storage (as would happen after
          // CacheEntry.toJson() serializes a custom object to a Map for Hive)
          final now = DateTime.now();
          final fakeEntry = CacheEntry<Map<String, dynamic>>(
            data: {'id': 1, 'title': 'Widget'},
            createdAt: now,
            ttl: const Duration(minutes: 5),
          );
          await persistentStorage.write('widget', fakeEntry);

          // Request as String — type mismatch, should fall through to fetcher
          var fetchCount = 0;
          final result = await cacheWithPersistent.get<String>(
            key: 'widget',
            fetcher: () async {
              fetchCount++;
              return 'fetched_string';
            },
            policy: CachePolicy.cacheFirst,
          );

          expect(result, 'fetched_string');
          expect(fetchCount, 1);
        },
      );

      test('cacheOnly: throws when persistent data type mismatches', () async {
        final now = DateTime.now();
        final fakeEntry = CacheEntry<Map<String, dynamic>>(
          data: {'id': 1, 'title': 'Widget'},
          createdAt: now,
          ttl: const Duration(minutes: 5),
        );
        await persistentStorage.write('widget', fakeEntry);

        expect(
          () => cacheWithPersistent.get<String>(
            key: 'widget',
            fetcher: () async => 'fetched',
            policy: CachePolicy.cacheOnly,
          ),
          throwsException,
        );
      });

      test(
        'staleWhileRevalidate: falls through to fetcher when persistent data type mismatches',
        () async {
          final now = DateTime.now();
          final fakeEntry = CacheEntry<Map<String, dynamic>>(
            data: {'id': 1, 'title': 'Widget'},
            createdAt: now,
            ttl: const Duration(minutes: 5),
          );
          await persistentStorage.write('widget', fakeEntry);

          var fetchCount = 0;
          final result = await cacheWithPersistent.get<String>(
            key: 'widget',
            fetcher: () async {
              fetchCount++;
              return 'fetched_string';
            },
            policy: CachePolicy.staleWhileRevalidate,
          );

          expect(result, 'fetched_string');
          expect(fetchCount, 1);
        },
      );
    });
  });

  group('CacheEntry serialization', () {
    test('toJson serializes primitives directly', () {
      final entry = CacheEntry<String>(
        data: 'hello',
        createdAt: DateTime(2024, 1, 1),
        ttl: const Duration(minutes: 5),
      );
      final json = entry.toJson();
      expect(json['data'], 'hello');
      expect(json['createdAt'], '2024-01-01T00:00:00.000');
      expect(json['ttl'], 300000);
    });

    test('toJson serializes numbers directly', () {
      final entry = CacheEntry<int>(data: 42, createdAt: DateTime(2024, 1, 1));
      final json = entry.toJson();
      expect(json['data'], 42);
    });

    test('toJson serializes custom objects via toJson()', () {
      final entry = CacheEntry<_TestModel>(
        data: _TestModel(id: 1, name: 'widget'),
        createdAt: DateTime(2024, 1, 1),
      );
      final json = entry.toJson();
      expect(json['data'], isA<Map<dynamic, dynamic>>());
      expect(json['data']['id'], 1);
      expect(json['data']['name'], 'widget');
    });

    test('toJson serializes lists containing custom objects', () {
      final entry = CacheEntry<List<_TestModel>>(
        data: [
          _TestModel(id: 1, name: 'a'),
          _TestModel(id: 2, name: 'b'),
        ],
        createdAt: DateTime(2024, 1, 1),
      );
      final json = entry.toJson();
      expect(json['data'], isA<List<dynamic>>());
      expect(json['data'][0]['id'], 1);
      expect(json['data'][1]['name'], 'b');
    });

    test('fromJson roundtrips with primitive data', () {
      final original = CacheEntry<String>(
        data: 'hello',
        createdAt: DateTime(2024, 1, 1),
        ttl: const Duration(minutes: 5),
      );
      final json = original.toJson();
      final restored = CacheEntry<dynamic>.fromJson(json);
      expect(restored.data, 'hello');
      expect(restored.createdAt, original.createdAt);
      expect(restored.ttl, original.ttl);
    });

    test('fromJson roundtrips with serialized custom object as Map', () {
      final original = CacheEntry<_TestModel>(
        data: _TestModel(id: 1, name: 'widget'),
        createdAt: DateTime(2024, 1, 1),
      );
      final json = original.toJson();
      // After toJson, data is a Map (serialized custom object)
      final restored = CacheEntry<dynamic>.fromJson(json);
      expect(restored.data, isA<Map>());
      expect((restored.data as Map)['id'], 1);
    });
  });

  group('TypeAdapter round-trip', () {
    late CacheNexusManager cache;
    late MemoryCacheStorage storage;

    setUp(() {
      NetworkStatus.setMockStatus(true);
      storage = MemoryCacheStorage();
      cache = CacheNexusManager(memoryStorage: storage);
      cache.registerAdapter<List<_Post>>(_ListPostAdapter());
    });

    tearDown(() {
      cache.dispose();
    });

    test('Post stored and retrieved as Post, not Map', () async {
      final posts = [_Post(id: 1, title: 'Hello', body: 'World')];
      await cache.set(key: 'posts', data: posts);

      final result = await cache.get<List<_Post>>(
        key: 'posts',
        fetcher: () async => [],
        policy: CachePolicy.cacheOnly,
      );

      expect(result, isA<List<_Post>>());
      expect(result[0], isA<_Post>());
      expect(result[0].id, 1);
      expect(result[0].title, 'Hello');
      expect(result[0].body, 'World');
    });

    test('Multiple posts round-trip correctly', () async {
      final posts = [
        _Post(id: 1, title: 'First', body: 'Body 1'),
        _Post(id: 2, title: 'Second', body: 'Body 2'),
        _Post(id: 3, title: 'Third', body: 'Body 3'),
      ];
      await cache.set(key: 'posts', data: posts);

      final result = await cache.get<List<_Post>>(
        key: 'posts',
        fetcher: () async => [],
        policy: CachePolicy.cacheOnly,
      );

      expect(result.length, 3);
      expect(result[0], isA<_Post>());
      expect(result[1], isA<_Post>());
      expect(result[2], isA<_Post>());
      expect(result[0].title, 'First');
      expect(result[2].title, 'Third');
    });

    test('cacheFirst fetcher returns posts when cache is empty', () async {
      final result = await cache.get<List<_Post>>(
        key: 'posts',
        fetcher: () async => [_Post(id: 1, title: 'Fetched', body: 'Body')],
        policy: CachePolicy.cacheFirst,
      );

      expect(result[0], isA<_Post>());
      expect(result[0].title, 'Fetched');

      final cached = await cache.get<List<_Post>>(
        key: 'posts',
        fetcher: () async => [],
        policy: CachePolicy.cacheOnly,
      );
      expect(cached[0], isA<_Post>());
      expect(cached[0].title, 'Fetched');
    });

    test(
      'cacheFirst calls fetcher on miss when no adapter and data is Map',
      () async {
        final cacheWithoutAdapter = CacheNexusManager(
          memoryStorage: MemoryCacheStorage(),
        );

        final now = DateTime.now();
        final fakeEntry = CacheEntry<Map<String, dynamic>>(
          data: {'id': 1, 'title': 'Widget'},
          createdAt: now,
          ttl: const Duration(minutes: 5),
        );
        await (cacheWithoutAdapter.memoryStorage as MemoryCacheStorage).write(
          'widget',
          fakeEntry,
        );

        var fetchCount = 0;
        final result = await cacheWithoutAdapter.get<String>(
          key: 'widget',
          fetcher: () async {
            fetchCount++;
            return 'fetched_string';
          },
          policy: CachePolicy.cacheFirst,
        );

        expect(result, 'fetched_string');
        expect(fetchCount, 1);
        cacheWithoutAdapter.dispose();
      },
    );
  });

  group('CacheNexusManager coverage', () {
    late CacheNexusManager cache;
    late MemoryCacheStorage storage;

    setUp(() {
      NetworkStatus.setMockStatus(true);
      storage = MemoryCacheStorage();
      cache = CacheNexusManager(
        memoryStorage: storage,
        mode: CacheNexusMode.dev,
      );
    });

    tearDown(() {
      cache.dispose();
    });

    test('clear() emits evict event with key all', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      await cache.set(key: 'a', data: 1);
      await cache.set(key: 'b', data: 2);
      await Future<void>.delayed(Duration(milliseconds: 10));

      await cache.clear();
      await Future<void>.delayed(Duration(milliseconds: 10));

      final evicts = events
          .where((e) => e.type == CacheEventType.evict)
          .toList();
      expect(evicts.any((e) => e.key == 'all'), isTrue);
    });

    test('dispose() cleans up reactive engine and observability', () async {
      final manager = CacheNexusManager(
        memoryStorage: MemoryCacheStorage(),
        mode: CacheNexusMode.dev,
      );
      manager.watch<String>('test').listen((_) {});
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(manager.reactiveEngine.controllerCount, 1);

      manager.dispose();
      await Future<void>.delayed(Duration(milliseconds: 50));

      expect(manager.reactiveEngine.controllerCount, 0);

      final done = Completer<void>();
      manager.events.listen((_) {}, onDone: () => done.complete());
      await Future<void>.delayed(Duration(milliseconds: 50));
      expect(done.isCompleted, isTrue);
    });

    test('watch with debounce debounces rapid updates', () async {
      final values = <String?>[];
      final sub = cache
          .watch<String>('debounce', debounce: Duration(milliseconds: 100))
          .listen((v) => values.add(v));

      await Future<void>.delayed(Duration(milliseconds: 10));
      await cache.set(key: 'debounce', data: 'a');
      await Future<void>.delayed(Duration(milliseconds: 20));
      await cache.set(key: 'debounce', data: 'b');
      await Future<void>.delayed(Duration(milliseconds: 20));
      await cache.set(key: 'debounce', data: 'c');

      await Future<void>.delayed(Duration(milliseconds: 200));

      expect(values, contains('c'));
      expect(values.length, lessThanOrEqualTo(3));

      await sub.cancel();
    });

    test('set and get with context isolation', () async {
      cache.setContext(CacheContext(userId: 'u1'));
      await cache.set(key: 'profile', data: 'Alice');

      cache.setContext(CacheContext(userId: 'u2'));
      await cache.set(key: 'profile', data: 'Bob');

      cache.setContext(CacheContext(userId: 'u1'));
      final a = await cache.get<String>(
        key: 'profile',
        fetcher: () async => 'default',
        policy: CachePolicy.cacheOnly,
      );
      expect(a, 'Alice');

      cache.setContext(CacheContext(userId: 'u2'));
      final b = await cache.get<String>(
        key: 'profile',
        fetcher: () async => 'default',
        policy: CachePolicy.cacheOnly,
      );
      expect(b, 'Bob');
    });

    test('invalidateByContext removes only that user cache', () async {
      cache.setContext(CacheContext(userId: 'keep'));
      await cache.set(key: 'k', data: 'keep_data');

      cache.setContext(CacheContext(userId: 'drop'));
      await cache.set(key: 'k', data: 'drop_data');

      await cache.invalidateByContext(CacheContext(userId: 'drop'));

      cache.setContext(CacheContext(userId: 'keep'));
      final keep = await cache.get<String>(
        key: 'k',
        fetcher: () async => '',
        policy: CachePolicy.cacheOnly,
      );
      expect(keep, 'keep_data');

      cache.setContext(CacheContext(userId: 'drop'));
      expect(
        () => cache.get<String>(
          key: 'k',
          fetcher: () async => '',
          policy: CachePolicy.cacheOnly,
        ),
        throwsException,
      );
    });

    test('networkFirst records observability events', () async {
      final events = <CacheEvent>[];
      cache.events.listen(events.add);

      await cache.get<String>(
        key: 'net',
        fetcher: () async => 'data',
        policy: CachePolicy.networkFirst,
      );

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(events.any((e) => e.type == CacheEventType.fetch), isTrue);
    });

    test('networkOnly always fetches', () async {
      await cache.set(key: 'nonly', data: 'old');
      var fetchCount = 0;

      final result = await cache.get<String>(
        key: 'nonly',
        fetcher: () async {
          fetchCount++;
          return 'fresh';
        },
        policy: CachePolicy.networkOnly,
      );

      expect(result, 'fresh');
      expect(fetchCount, 1);
    });
  });
}

class _TestModel {
  final int id;
  final String name;

  _TestModel({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

class _Post {
  final int id;
  final String title;
  final String body;

  _Post({required this.id, required this.title, required this.body});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};

  factory _Post.fromJson(Map<String, dynamic> json) => _Post(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ body.hashCode;
}

class _ListPostAdapter implements TypeAdapter<List<_Post>> {
  @override
  List<_Post> fromData(dynamic data) {
    if (data is List<_Post>) return data;
    if (data is List) {
      return data
          .map((e) => _Post.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  dynamic toData(List<_Post> value) => value.map((p) => p.toJson()).toList();
}
