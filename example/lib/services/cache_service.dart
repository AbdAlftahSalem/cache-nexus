import 'dart:convert';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/post.dart';
import 'api_service.dart';

class CacheService {
  final ApiService _api;
  final CacheNexusManager _cache;
  final SyncEngine _syncEngine;

  CacheService({
    required ApiService api,
    required CacheNexusManager cache,
    required SyncEngine syncEngine,
  }) : _api = api,
       _cache = cache,
       _syncEngine = syncEngine;

  CacheNexusManager get cache => _cache;
  SyncEngine get syncEngine => _syncEngine;

  static Future<CacheService> create() async {
    print('🔵 [CacheService] Creating cache with mode: CacheNexusMode.dev');
    final memoryStorage = MemoryCacheStorage();

    // Persistent, encrypted, compressed tier. Survives restarts.
    final hive = HiveCacheStorage(boxName: 'example_cache');
    await hive.init();
    final persistentStorage = SecureCacheStorage(
      hive,
      encryptor: AesGcmEncryptor.fromBase64(await _loadOrCreateKey()),
      compressor: const GZipCompressor(),
    );

    final cache = CacheNexusManager(
      memoryStorage: memoryStorage,
      persistentStorage: persistentStorage,
      syncEngine: null,
      mode: CacheNexusMode.dev,
    );

    // Lets List<Post> / Post be rebuilt from disk after a restart.
    cache.registerAdapter<Post>(
      CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
    );

    print('🔵 [CacheService] Creating ApiService with cache');
    final api = ApiService(cache: cache);

    final syncEngine = SyncEngine(
      executor: (task) async {
        try {
          if (task.method == 'POST') {
            final post = Post.fromJson(task.body as Map<String, dynamic>);
            await api.createPost(post);
          } else if (task.method == 'DELETE') {
            final id = task.body as int;
            await api.deletePost(id);
          }
          return true;
        } catch (_) {
          return false;
        }
      },
      queueBoxName: 'example_sync_queue',
      retryDelay: const Duration(seconds: 2),
    );
    await syncEngine.init();

    cache.syncEngine = syncEngine;

    print('🔵 [CacheService] CacheService created successfully');
    return CacheService(api: api, cache: cache, syncEngine: syncEngine);
  }

  /// Demo only: the AES key lives in its own Hive box. In a real app keep it
  /// in the platform keystore (e.g. flutter_secure_storage).
  static Future<String> _loadOrCreateKey() async {
    final box = await Hive.openBox<String>('example_keys');
    var key = box.get('cache_key');
    if (key == null) {
      key = base64Encode(AesGcmEncryptor.generateKey());
      await box.put('cache_key', key);
    }
    return key;
  }

  Future<List<Post>> getPosts({
    CachePolicy policy = CachePolicy.cacheFirst,
    Duration? ttl,
  }) {
    return _cache.get<List<Post>>(
      key: 'posts',
      fetcher: () => _api.getPosts(),
      ttl: ttl ?? const Duration(minutes: 5),
      policy: policy,
    );
  }

  Future<Post> getPost(
    int id, {
    CachePolicy policy = CachePolicy.cacheFirst,
    Duration? ttl,
  }) {
    return _cache.get<Post>(
      key: 'post_$id',
      fetcher: () => _api.getPost(id),
      ttl: ttl ?? const Duration(minutes: 5),
      policy: policy,
    );
  }

  Future<void> enqueueCreatePost(Post post) async {
    await _cache.enqueueSyncTask(
      SyncTask(
        id: 'create_post_${DateTime.now().millisecondsSinceEpoch}',
        key: 'post_new',
        endpoint: 'https://jsonplaceholder.typicode.com/posts',
        method: 'POST',
        body: post.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> enqueueDeletePost(int id) async {
    await _cache.enqueueSyncTask(
      SyncTask(
        id: 'delete_post_${DateTime.now().millisecondsSinceEpoch}',
        key: 'post_$id',
        endpoint: 'https://jsonplaceholder.typicode.com/posts/$id',
        method: 'DELETE',
        body: id,
        createdAt: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _cache.dispose();
    _syncEngine.dispose();
  }
}
