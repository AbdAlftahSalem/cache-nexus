import 'cache_entry.dart';
import 'cache_storage.dart';

class MemoryCacheStorage implements CacheStorage {
  final Map<String, CacheEntry> _cache = {};

  @override
  Future<void> write(String key, CacheEntry entry) async {
    _cache[key] = entry;
  }

  @override
  Future<CacheEntry?> read(String key) async {
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
