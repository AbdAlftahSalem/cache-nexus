import 'cache_entry.dart';
import 'cache_storage.dart';

/// An in-process [CacheStorage]. Fast, but empty after an app restart.
///
/// Values are kept as-is (no serialization), so memory hits return the
/// exact objects that were stored.
class MemoryCacheStorage implements CacheStorage {
  final Map<String, CacheEntry<dynamic>> _cache = {};

  /// Creates an empty memory storage.
  MemoryCacheStorage();

  /// The keys currently stored.
  Iterable<String> get keys => _cache.keys;

  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) async {
    _cache[key] = entry;
  }

  @override
  Future<CacheEntry<dynamic>?> read(String key) async {
    return _cache[key];
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }
}
