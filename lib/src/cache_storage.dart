import 'cache_entry.dart';

abstract class CacheStorage {
  Future<void> write(String key, CacheEntry entry);
  Future<CacheEntry?> read(String key);
  Future<void> delete(String key);
  Future<void> clear();
}
