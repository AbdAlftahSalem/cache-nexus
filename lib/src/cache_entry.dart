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

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'ttl': ttl?.inMilliseconds,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'] as T,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ttl: json['ttl'] != null ? Duration(milliseconds: json['ttl'] as int) : null,
    );
  }
}
