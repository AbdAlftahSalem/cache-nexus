// A console-style tour of cache_nexus. For the full Flutter app see lib/.
// ignore_for_file: avoid_print
import 'package:cache_nexus/cache_nexus.dart';

class Post {
  Post(this.id, this.title);
  factory Post.fromJson(Map<String, dynamic> json) =>
      Post(json['id'] as int, json['title'] as String);
  final int id;
  final String title;
  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

Future<void> main() async {
  // 1. Encrypted persistent tier. In an app, wrap HiveCacheStorage (after
  //    `await hive.init()`) and load the key from secure storage.
  final persistent = SecureCacheStorage(
    MemoryCacheStorage(),
    encryptor: AesGcmEncryptor(AesGcmEncryptor.generateKey()),
    compressor: const GZipCompressor(),
  );

  final cache = CacheNexusManager(persistentStorage: persistent);

  // 2. Typed data that survives restarts.
  cache.registerAdapter<Post>(
    CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
  );

  final posts = await cache.get<List<Post>>(
    key: 'posts',
    fetcher: () async => [Post(1, 'مرحبا'), Post(2, 'Hello')],
    ttl: const Duration(minutes: 5),
  );
  print('Fetched ${posts.length} posts');

  // Served from cache: the fetcher is not called again.
  final cached = await cache.get<List<Post>>(
    key: 'posts',
    fetcher: () async => throw StateError('not called'),
  );
  print('From cache: ${cached.map((p) => p.title).join(', ')}');

  // 3. Per-user isolation.
  cache.setContext(const CacheContext(userId: 'user_123', role: 'admin'));
  await cache.set<String>(key: 'secret', data: 'Admin only');
  cache.setContext(const CacheContext(userId: 'user_456'));
  final guest = await cache.get<String?>(
    key: 'secret',
    fetcher: () async => null,
    policy: CachePolicy.cacheOnly,
  );
  print('Guest sees: $guest'); // null

  // 4. Logout: wipe user_123's data and notify watchers.
  await cache.invalidateByContext(const CacheContext(userId: 'user_123'));
  cache.clearContext();

  // 5. Stale-while-revalidate: instant answer, background refresh.
  final feed = await cache.get<String>(
    key: 'feed',
    fetcher: () async => 'fresh feed',
    policy: CachePolicy.staleWhileRevalidate,
  );
  print('Feed: $feed');

  cache.dispose();
}
