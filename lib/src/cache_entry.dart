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
      'data': _serializeData(data),
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

  static dynamic _serializeData(dynamic data) {
    if (data == null || data is String || data is num || data is bool) return data;
    if (data is List) return data.map((e) => _serializeData(e)).toList();
    if (data is Map) return data.map((k, v) => MapEntry(k, _serializeData(v)));
    try {
      return (data as dynamic).toJson();
    } catch (_) {
      return data.toString();
    }
  }
}
