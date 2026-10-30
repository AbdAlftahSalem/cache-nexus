/// Thrown (or reported as an error event) when a cached value exists but
/// cannot be converted to the requested type.
///
/// The usual cause is a custom class read back from disk after a restart
/// without a registered [CacheAdapter].
class CacheDecodeException implements Exception {
  /// Creates a decode exception for [key].
  const CacheDecodeException({
    required this.key,
    required this.requestedType,
    required this.storedType,
    this.cause,
  });

  /// The (resolved) cache key whose value could not be decoded.
  final String key;

  /// The type the caller asked for, e.g. `List<Post>`.
  final String requestedType;

  /// The runtime type found in the cache, e.g. `List<dynamic>`.
  final String storedType;

  /// The error thrown by the adapter, if one was involved.
  final Object? cause;

  @override
  String toString() {
    final hint = cause != null
        ? 'The registered adapter threw: $cause'
        : 'Register an adapter for the element type, for example '
              'cache.registerAdapter<YourType>(CacheAdapter.json('
              'fromJson: YourType.fromJson, toJson: (v) => v.toJson())).';
    return 'CacheDecodeException: the cached value for "$key" is a '
        '$storedType and cannot be read as $requestedType. $hint';
  }
}

/// Thrown when a cache-only read (or an offline `networkFirst` read) finds no
/// usable entry for a key.
class CacheMissException implements Exception {
  /// Creates a miss exception for [key].
  const CacheMissException(this.key);

  /// The (resolved) cache key that was not found or had expired.
  final String key;

  @override
  String toString() => 'Exception: Cache missing or expired for key: $key';
}
