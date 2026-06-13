class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration? ttl;

  CacheEntry({
    required this.data,
    required this.createdAt,
    this.ttl,
  });

  bool get isExpired {
    if (ttl == null) return false;
    final expirationDate = createdAt.add(ttl!);
    return DateTime.now().isAfter(expirationDate);
  }
}
