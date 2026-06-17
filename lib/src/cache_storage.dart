import 'cache_entry.dart';

abstract class CacheStorage {
  Future<void> write(String key, CacheEntry<dynamic> entry);
  Future<CacheEntry<dynamic>?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteByPrefix(String prefix);
  Future<void> clear();
}
