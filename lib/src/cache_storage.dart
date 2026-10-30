import 'cache_entry.dart';

/// A storage tier used by `CacheNexusManager`.
///
/// Implement this to plug in another backend (SQLite, files, ...).
/// Persistent implementations should store JSON-like data (see
/// [CacheEntry.toJson]).
abstract class CacheStorage {
  /// Stores [entry] under [key], replacing any previous value.
  Future<void> write(String key, CacheEntry<dynamic> entry);

  /// Returns the entry for [key], or `null`. Expired entries are returned
  /// too; callers check [CacheEntry.isExpired].
  Future<CacheEntry<dynamic>?> read(String key);

  /// Removes [key].
  Future<void> delete(String key);

  /// Removes every key starting with [prefix].
  Future<void> deleteByPrefix(String prefix);

  /// Removes everything.
  Future<void> clear();
}
