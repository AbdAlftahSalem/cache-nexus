enum CacheEventType {
  hit,
  miss,
  fetch,
  store,
  error,
  expired,
  evict,
  networkRequest,
  networkResponse,
  networkError,
}

class CacheEvent {
  final String key;
  final CacheEventType type;
  final DateTime timestamp;
  final dynamic data;
  final Duration? duration;
  final Object? error;

  // Network request fields
  final String? url;
  final String? method;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final int? responseStatusCode;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final String? requestId;

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

  bool get isNetworkEvent => type == CacheEventType.networkRequest ||
      type == CacheEventType.networkResponse ||
      type == CacheEventType.networkError;

  @override
  String toString() {
    return 'CacheEvent(key: $key, type: $type, timestamp: $timestamp, duration: ${duration?.inMilliseconds}ms)';
  }
}
