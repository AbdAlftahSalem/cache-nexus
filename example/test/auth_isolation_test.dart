import 'package:flutter_test/flutter_test.dart';
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  late CacheNexusManager cache;
  late MemoryCacheStorage memory;
  late MemoryCacheStorage persistent;

  setUp(() {
    memory = MemoryCacheStorage();
    persistent = MemoryCacheStorage();
    cache = CacheNexusManager(
      memoryStorage: memory,
      persistentStorage: persistent,
    );
  });

  tearDown(() {
    cache.dispose();
  });

  test('admin and guest have isolated cache', () async {
    cache.setContext(const CacheContext(userId: 'admin_001', role: 'admin'));
    await cache.set(key: 'profile', data: 'Admin Profile');

    cache.setContext(const CacheContext(userId: 'guest_002', role: 'guest'));
    await cache.set(key: 'profile', data: 'Guest Profile');

    cache.setContext(const CacheContext(userId: 'admin_001', role: 'admin'));
    final admin = await cache.get<String>(
      key: 'profile',
      fetcher: () async => 'default',
    );
    expect(admin, 'Admin Profile');

    cache.setContext(const CacheContext(userId: 'guest_002', role: 'guest'));
    final guest = await cache.get<String>(
      key: 'profile',
      fetcher: () async => 'default',
    );
    expect(guest, 'Guest Profile');
  });

  test('invalidateByContext clears only target user', () async {
    const ctxA = CacheContext(userId: 'user_a');
    const ctxB = CacheContext(userId: 'user_b');

    cache.setContext(ctxA);
    await cache.set(key: 'data', data: 'Data A');

    cache.setContext(ctxB);
    await cache.set(key: 'data', data: 'Data B');

    await cache.invalidateByContext(ctxA);

    cache.setContext(ctxA);
    expect(
      () => cache.get<String>(
        key: 'data',
        fetcher: () async => 'Miss',
        policy: CachePolicy.cacheOnly,
      ),
      throwsException,
    );

    cache.setContext(ctxB);
    final data = await cache.get<String>(
      key: 'data',
      fetcher: () async => 'Fresh B',
    );
    expect(data, 'Data B');
  });

  test('role-based isolation', () async {
    const adminCtx = CacheContext(userId: '123', role: 'admin');
    const userCtx = CacheContext(userId: '123', role: 'user');

    cache.setContext(adminCtx);
    await cache.set(key: 'settings', data: 'Admin Settings');

    cache.setContext(userCtx);
    await cache.set(key: 'settings', data: 'User Settings');

    cache.setContext(adminCtx);
    expect(
      await cache.get<String>(key: 'settings', fetcher: () async => ''),
      'Admin Settings',
    );

    cache.setContext(userCtx);
    expect(
      await cache.get<String>(key: 'settings', fetcher: () async => ''),
      'User Settings',
    );
  });

  test('clearContext restores global access', () async {
    cache.setContext(const CacheContext(userId: 'user_a'));
    await cache.set(key: 'global_key', data: 'User A data');

    cache.clearContext();
    await cache.set(key: 'global_key', data: 'Global data');

    final result = await cache.get<String>(
      key: 'global_key',
      fetcher: () async => 'default',
    );
    expect(result, 'Global data');
  });
}
