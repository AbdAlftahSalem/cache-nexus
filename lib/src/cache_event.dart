enum CacheEventType {
  hit,
  miss,
  fetch,
  store,
  error,
  expired,
  evict,
}

class CacheEvent {
  final String key;
  final CacheEventType type;
  final DateTime timestamp;
  final dynamic data;
  final Duration? duration;
  final Object? error;

  CacheEvent({
    required this.key,
    required this.type,
    required this.timestamp,
    this.data,
    this.duration,
    this.error,
  });

  @override
  String toString() {
    return 'CacheEvent(key: $key, type: $type, timestamp: $timestamp, duration: ${duration?.inMilliseconds}ms)';
  }
}
