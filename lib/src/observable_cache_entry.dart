import 'dart:async';

import 'cache_entry.dart';

/// A reactive cache entry that can notify listeners of data changes.
class ObservableCacheEntry<T> {
  T data;
  final DateTime createdAt;
  final Duration? ttl;

  // ignore: prefer_function_over_method
  final _controller = StreamController<T>.broadcast();

  ObservableCacheEntry({
    required this.data,
    required this.createdAt,
    this.ttl,
  });

  bool get isExpired {
    final t = ttl;
    if (t == null) return false;
    final expirationDate = createdAt.add(t);
    return DateTime.now().isAfter(expirationDate);
  }

  /// Updates the data and notifies all listeners.
  void update(T newData) {
    data = newData;
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  /// Emits the current value to a new listener on subscription.
  Stream<T> get stream => Stream.fromFuture(Future.value(data)).followedBy(_controller.stream);

  /// Direct stream access for advanced usage.
  StreamController<T> get controller => _controller;

  /// Disposes the internal stream controller.
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  CacheEntry<T> toCacheEntry() {
    return CacheEntry<T>(
      data: data,
      createdAt: createdAt,
      ttl: ttl,
    );
  }

  factory ObservableCacheEntry.fromCacheEntry(CacheEntry<T> entry) {
    return ObservableCacheEntry<T>(
      data: entry.data,
      createdAt: entry.createdAt,
      ttl: entry.ttl,
    );
  }
}

extension _StreamFollowedBy<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> other) {
    final controller = StreamController<T>();
    listen(
      controller.add,
      onError: controller.addError,
      onDone: () {
        other.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
    );
    return controller.stream;
  }
}
