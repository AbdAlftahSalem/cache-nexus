import 'package:smart_cache/smart_cache.dart';
import '../models/post.dart';
import 'api_service.dart';

class CacheService {
  final ApiService _api;
  final SmartCacheManager _cache;
  final SyncEngine _syncEngine;

  CacheService({
    required ApiService api,
    required SmartCacheManager cache,
    required SyncEngine syncEngine,
  }) : _api = api,
       _cache = cache,
       _syncEngine = syncEngine;

  SmartCacheManager get cache => _cache;
  SyncEngine get syncEngine => _syncEngine;

  static Future<CacheService> create() async {
    print('🔵 [CacheService] Creating cache with mode: SmartCacheMode.dev');
    final memoryStorage = MemoryCacheStorage();

    final persistentStorage = SecureCacheStorage(
      MemoryCacheStorage(),
      encryptor: SimpleEncryptor('example_secret_key'),
      compressor: SimpleCompressor(),
    );

    final cache = SmartCacheManager(
      memoryStorage: memoryStorage,
      persistentStorage: persistentStorage,
      syncEngine: null,
      mode: SmartCacheMode.dev,
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
    );
    await syncEngine.init();

    cache.syncEngine = syncEngine;

    print('🔵 [CacheService] CacheService created successfully');
    return CacheService(api: api, cache: cache, syncEngine: syncEngine);
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
