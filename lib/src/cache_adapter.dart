/// Converts a typed value to a storable form and back.
///
/// Persistent storages (Hive, [SecureCacheStorage](package:cache_nexus/cache_nexus.dart))
/// can only hold JSON-like data: `null`, `bool`, `num`, `String`, `List` and
/// `Map`. After an app restart a cached `Post` therefore comes back as a
/// `Map<String, dynamic>`. Register a [CacheAdapter] so `cache_nexus` can
/// rebuild your type:
///
/// ```dart
/// cache.registerAdapter<Post>(
///   CacheAdapter.json(fromJson: Post.fromJson, toJson: (p) => p.toJson()),
/// );
/// ```
///
/// Registering an adapter for `Post` also teaches the cache how to read
/// `List<Post>` and `Map<String, Post>`, so `get<List<Post>>` survives a
/// restart without any extra code.
///
/// [fromData] receives data that has already been normalised: maps arrive as
/// `Map<String, dynamic>` and lists as `List<dynamic>`. It is only called when
/// the cached value is not already a `T` (memory hits skip it).
abstract class CacheAdapter<T> {
  /// Const constructor so subclasses can be `const`.
  const CacheAdapter();

  /// Creates an adapter from a `fromJson` factory and a `toJson` function.
  const factory CacheAdapter.json({
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
  }) = JsonCacheAdapter<T>;

  /// Rebuilds a [T] from its stored representation.
  T fromData(dynamic data);

  /// Converts [value] to a JSON-like representation (`Map`, `List`, `String`,
  /// `num`, `bool` or `null`) that every storage can persist.
  dynamic toData(T value);
}

/// A [CacheAdapter] built from a `fromJson` / `toJson` pair.
///
/// Usually created through [CacheAdapter.json].
class JsonCacheAdapter<T> implements CacheAdapter<T> {
  /// Creates an adapter that delegates to [fromJson] and [toJson].
  const JsonCacheAdapter({required this.fromJson, required this.toJson});

  /// Builds a [T] from a JSON map.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Converts a [T] to a JSON map.
  final Map<String, dynamic> Function(T value) toJson;

  @override
  T fromData(dynamic data) {
    if (data is Map<String, dynamic>) return fromJson(data);
    if (data is Map) return fromJson(Map<String, dynamic>.from(data));
    throw FormatException(
      'JsonCacheAdapter<$T> expected a Map but got ${data.runtimeType}',
    );
  }

  @override
  dynamic toData(T value) => toJson(value);
}
