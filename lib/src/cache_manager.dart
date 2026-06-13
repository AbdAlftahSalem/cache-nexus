import 'cache_entry.dart';
import 'cache_storage.dart';

class SmartCacheManager {
  final CacheStorage storage;

  SmartCacheManager({required this.storage});

  Future<T> get<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
  }) async {
    final entry = await storage.read(key);

    if (entry != null && !entry.isExpired) {
      return entry.data as T;
    }

    final result = await fetcher();

    // ignore: unnecessary_null_comparison
    if (result == null) {
      throw Exception('Fetcher returned null result for key: $key');
    }

    await set(key: key, data: result, ttl: ttl);

    return result;
  }

  Future<void> set<T>({
    required String key,
    required T data,
    Duration? ttl,
  }) async {
    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    await storage.write(key, entry);
  }

  Future<void> delete(String key) async {
    await storage.delete(key);
  }

  Future<void> clear() async {
    await storage.clear();
  }
}
