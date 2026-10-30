import 'dart:async';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => NetworkStatus.setMockStatus(true));

  group('CacheContext', () {
    test('prefixes are length-prefixed and role-aware', () {
      const plain = CacheContext(userId: 'ali');
      const admin = CacheContext(userId: 'ali', role: 'admin', token: 't');
      expect(plain.userKeyPrefix, 'u3:ali|');
      expect(plain.cacheKeyPrefix, 'u3:ali|r|');
      expect(admin.cacheKeyPrefix, 'u3:ali|r5:admin|');
      expect(plain.legacyCacheKeyPrefix, 'ali_');
      expect(admin.legacyCacheKeyPrefix, 'ali_admin_');
      expect(admin.toString(), 'CacheContext(userId: ali, role: admin)');
      expect(
        admin,
        const CacheContext(userId: 'ali', role: 'admin', token: 't'),
      );
      expect(admin.hashCode, isNot(plain.hashCode));
      expect(admin == plain, isFalse);
    });

    test('invalidate: role-less wipes every role, role wipes one', () async {
      final storage = MemoryCacheStorage();
      final cache = CacheNexusManager(persistentStorage: storage);
      Future<void> put(CacheContext c, String v) async {
        cache.setContext(c);
        await cache.set(key: 'k', data: v);
      }

      const plain = CacheContext(userId: 'ali');
      const admin = CacheContext(userId: 'ali', role: 'admin');
      const other = CacheContext(userId: 'ali_admin');
      await put(plain, 'p');
      await put(admin, 'a');
      await put(other, 'o');
      expect(storage.keys, hasLength(3));

      await cache.invalidateByContext(admin);
      expect(storage.keys.toSet(), {'u3:ali|r|k', 'u9:ali_admin|r|k'});
      await cache.invalidateByContext(plain);
      expect(storage.keys.toSet(), {'u9:ali_admin|r|k'});
      cache.clearContext();
      expect(cache.context, isNull);
    });

    test('1.0 role-scoped keys are migrated on first read', () async {
      final storage = MemoryCacheStorage();
      await storage.write(
        'ali_admin_k',
        CacheEntry<String>(data: 'legacy', createdAt: DateTime.now()),
      );
      final cache = CacheNexusManager(
        persistentStorage: storage,
        context: const CacheContext(userId: 'ali', role: 'admin'),
      );
      expect(
        await cache.get<String>(key: 'k', fetcher: () async => 'net'),
        'legacy',
      );
      expect(storage.keys, ['u3:ali|r5:admin|k']);
    });
  });

  group('manager behaviour', () {
    test('SWR background failures become error events, not crashes', () async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      await cache.set(key: 'k', data: 'cached');
      final v = await cache.get<String>(
        key: 'k',
        fetcher: () async => throw Exception('server down'),
        policy: CachePolicy.staleWhileRevalidate,
      );
      expect(v, 'cached');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        cache.recentEvents.where((e) => e.type == CacheEventType.error),
        isNotEmpty,
      );
    });

    test('SWR does not revalidate while offline', () async {
      final cache = CacheNexusManager();
      await cache.set(key: 'k', data: 'cached');
      NetworkStatus.setMockStatus(false);
      var fetches = 0;
      await cache.get<String>(
        key: 'k',
        fetcher: () async {
          fetches++;
          return 'x';
        },
        policy: CachePolicy.staleWhileRevalidate,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fetches, 0);
    });

    test('a failing persistent write does not fail the fetch', () async {
      final cache = CacheNexusManager(
        persistentStorage: _ThrowingStorage(),
        mode: CacheNexusMode.dev,
      );
      expect(await cache.get<String>(key: 'k', fetcher: () async => 'v'), 'v');
      expect(
        cache.recentEvents.where((e) => e.type == CacheEventType.error),
        isNotEmpty,
      );
    });

    test('same key requested with two types fetches independently', () async {
      final cache = CacheNexusManager();
      final gate = Completer<void>();
      final a = cache.get<String>(
        key: 'k',
        fetcher: () async {
          await gate.future;
          return 's';
        },
      );
      final b = cache.get<int>(key: 'k', fetcher: () async => 1);
      gate.complete();
      expect(await a, 's');
      expect(await b, 1);
    });

    test('cacheOnly on an expired entry is a miss', () async {
      final cache = CacheNexusManager();
      await cache.set(
        key: 'k',
        data: 'v',
        ttl: const Duration(milliseconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await expectLater(
        cache.get<String>(
          key: 'k',
          fetcher: () async => 'x',
          policy: CachePolicy.cacheOnly,
        ),
        throwsA(isA<CacheMissException>()),
      );
      expect(
        await cache.get<String?>(
          key: 'k',
          fetcher: () async => 'x',
          policy: CachePolicy.cacheOnly,
        ),
        isNull,
      );
    });

    test('watch reads typed values from persistent storage', () async {
      final storage = MemoryCacheStorage();
      await storage.write(
        'list',
        CacheEntry<dynamic>(data: <dynamic>['a'], createdAt: DateTime.now()),
      );
      await storage.write(
        'bad',
        CacheEntry<dynamic>(data: 'x', createdAt: DateTime.now()),
      );
      final cache = CacheNexusManager(persistentStorage: storage);
      expect(await cache.watch<List<String>>('list').first, ['a']);
      await expectLater(
        cache.watch<int>('bad').first,
        throwsA(isA<CacheDecodeException>()),
      );
      expect(cache.tryCast<List<String>>(<dynamic>['z']), ['z']);
      expect(cache.tryCast<int>('nope'), isNull);
    });

    test('watch after dispose completes immediately', () async {
      final cache = CacheNexusManager();
      cache.dispose();
      cache.dispose();
      expect(await cache.watch<String>('k').toList(), isEmpty);
    });

    test('debounced watchers get only the last value', () async {
      final cache = CacheNexusManager();
      final seen = <String?>[];
      final sub = cache
          .watch<String>('d', debounce: const Duration(milliseconds: 20))
          .listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      seen.clear();
      for (final v in ['1', '2', '3']) {
        await cache.set(key: 'd', data: v);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(seen, ['3']);
      await sub.cancel();
    });
  });

  test('SyncMetadata json round trip', () {
    final m = SyncMetadata(
      version: '3',
      updatedAt: DateTime(2026),
      deviceId: 'd',
    );
    final back = SyncMetadata.fromJson(m.toJson());
    expect(back.version, '3');
    expect(back.updatedAt, DateTime(2026));
    expect(back.deviceId, 'd');
  });

  test('CacheEntry helpers', () {
    final e = CacheEntry<String>(
      data: 'v',
      createdAt: DateTime(2026),
      ttl: const Duration(hours: 1),
    );
    expect(e.expiresAt, DateTime(2026, 1, 1, 1));
    expect(e.toString(), contains('v'));
    final back = CacheEntry<dynamic>.fromJson(<String, dynamic>{
      'data': <dynamic, dynamic>{'a': 1},
      'createdAt': '2026-01-01T00:00:00.000',
      'ttl': 1000,
    });
    expect(back.data, isA<Map<String, dynamic>>());
    expect(back.ttl, const Duration(seconds: 1));
  });

  test('CacheEvent and CacheStats helpers', () {
    final e = CacheEvent(
      key: 'k',
      type: CacheEventType.networkError,
      timestamp: DateTime(2026),
      duration: const Duration(milliseconds: 3),
    );
    expect(e.isNetworkEvent, isTrue);
    expect(e.toString(), contains('3ms'));
    final s = CacheStats(
      hits: 1,
      misses: 1,
      totalRequests: 1,
      successfulRequests: 1,
      totalResponseTimeMs: 10,
    );
    expect(s.hitRate, 0.5);
    expect(s.successRate, 1);
    expect(s.averageResponseTimeMs, 10);
    expect(s.toString(), contains('50.0%'));
    expect(CacheStats().successRate, 0);
    expect(CacheStats().averageResponseTimeMs, 0);
  });
}

class _ThrowingStorage implements CacheStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteByPrefix(String prefix) async {}
  @override
  Future<CacheEntry<dynamic>?> read(String key) async => null;
  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) =>
      throw StateError('disk full');
}
