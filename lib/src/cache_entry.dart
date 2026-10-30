import 'type_registry.dart';

/// A cached value together with the moment it was stored and its time to live.
class CacheEntry<T> {
  /// The cached value.
  final T data;

  /// When the value was stored.
  final DateTime createdAt;

  /// How long the value stays fresh. `null` means it never expires.
  final Duration? ttl;

  /// Creates an entry.
  CacheEntry({required this.data, required this.createdAt, this.ttl});

  /// The moment the entry stops being fresh, or `null` if it never expires.
  DateTime? get expiresAt => ttl == null ? null : createdAt.add(ttl!);

  /// Whether the entry is older than its [ttl].
  ///
  /// Expired entries are not deleted on read: `staleWhileRevalidate` still
  /// serves them while it refreshes in the background.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// Serializes the entry to a JSON-compatible map.
  ///
  /// Custom objects are converted through their `toJson()` method and
  /// `DateTime` values become ISO-8601 strings.
  Map<String, dynamic> toJson() {
    return {
      'data': CacheTypeRegistry.toStorable(data),
      'createdAt': createdAt.toIso8601String(),
      'ttl': ttl?.inMilliseconds,
    };
  }

  /// Restores an entry written by [toJson].
  ///
  /// Nested maps are normalised to `Map<String, dynamic>` so data read back
  /// from Hive (which returns `Map<dynamic, dynamic>`) is usable directly.
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: CacheTypeRegistry.normalize(json['data']) as T,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ttl: json['ttl'] != null
          ? Duration(milliseconds: (json['ttl'] as num).toInt())
          : null,
    );
  }

  @override
  String toString() =>
      'CacheEntry(createdAt: $createdAt, ttl: $ttl, data: $data)';
}
