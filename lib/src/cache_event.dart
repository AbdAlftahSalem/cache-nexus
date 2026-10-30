/// The kind of a [CacheEvent].
enum CacheEventType {
  /// A value was served from the cache.
  hit,

  /// Nothing usable was cached.
  miss,

  /// The fetcher returned a value.
  fetch,

  /// A value was written to the cache.
  store,

  /// Something failed (fetcher, storage, decoding).
  error,

  /// A cached entry was found but its TTL had passed.
  expired,

  /// Entries were removed (`delete`, `clear`, `invalidateByContext`).
  evict,

  /// An HTTP request started.
  networkRequest,

  /// An HTTP response arrived.
  networkResponse,

  /// An HTTP request failed.
  networkError,
}

/// Something that happened in the cache or on the network, recorded in
/// [CacheNexusMode.dev](package:cache_nexus/cache_nexus.dart).
class CacheEvent {
  /// The (resolved) cache key, or `network:<requestId>` for network events.
  final String key;

  /// What happened.
  final CacheEventType type;

  /// When it happened.
  final DateTime timestamp;

  /// The value involved, if any.
  final dynamic data;

  /// How long the operation took, if measured.
  final Duration? duration;

  /// The error, for [CacheEventType.error] and network errors.
  final Object? error;

  /// The request URL (network events).
  final String? url;

  /// The HTTP method (network events).
  final String? method;

  /// The request headers (sensitive ones redacted by the interceptor).
  final Map<String, dynamic>? requestHeaders;

  /// The request body.
  final dynamic requestBody;

  /// The HTTP status code of the response.
  final int? responseStatusCode;

  /// The response headers.
  final Map<String, dynamic>? responseHeaders;

  /// The response body.
  final dynamic responseBody;

  /// Links a request to its response or error.
  final String? requestId;

  /// Creates an event.
  CacheEvent({
    required this.key,
    required this.type,
    required this.timestamp,
    this.data,
    this.duration,
    this.error,
    this.url,
    this.method,
    this.requestHeaders,
    this.requestBody,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.requestId,
  });

  /// Whether this is a request, response or network error.
  bool get isNetworkEvent =>
      type == CacheEventType.networkRequest ||
      type == CacheEventType.networkResponse ||
      type == CacheEventType.networkError;

  @override
  String toString() {
    return 'CacheEvent(key: $key, type: $type, timestamp: $timestamp, duration: ${duration?.inMilliseconds}ms)';
  }
}
