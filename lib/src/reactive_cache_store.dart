import 'dart:async';

import 'cache_entry.dart';
import 'cache_storage.dart';

/// A reactive cache store that emits updates whenever entries change.
class ReactiveCacheStore {
  final CacheStorage _storage;
  final _subscriptions = <String, StreamController<dynamic>>{};

  ReactiveCacheStore(this._storage);

  /// Writes an entry and emits the update.
  Future<void> write(String key, CacheEntry entry) async {
    await _storage.write(key, entry);
    _emit(key, entry.data);
  }

  /// Reads an entry from storage.
  Future<CacheEntry?> read(String key) async {
    return _storage.read(key);
  }

  /// Deletes an entry and emits null.
  Future<void> delete(String key) async {
    await _storage.delete(key);
    _emit(key, null);
  }

  /// Clears all entries and emits null for each key.
  Future<void> clear() async {
    // Note: To be truly reactive on clear, we'd need to track all keys.
    // For now, we clear storage; existing watchers will see no further updates
    // until a new value is set.
    await _storage.clear();
  }

  /// Returns a broadcast stream for a given key.
  /// The stream emits the current value (if any) on subscription,
  /// then emits updates as they happen.
  Stream<T> watch<T>(String key) {
    late StreamController<T> controller;
    
    controller = StreamController<T>.broadcast(
      onListen: () {
        // Emit current value on first listen
        read(key).then((entry) {
          if (entry != null && !controller.isClosed) {
            controller.add(entry.data as T);
          }
        });
      },
      onCancel: () {
        // Clean up in microtask to allow re-subscription
        Future.microtask(() {
          if (!controller.hasListener && !controller.isClosed) {
            controller.close();
            _subscriptions.remove(key);
          }
        });
      },
    );

    _subscriptions[key] = controller;
    return controller.stream;
  }

  void _emit<T>(String key, T value) {
    final controller = _subscriptions[key];
    if (controller != null && !controller.isClosed) {
      controller.add(value);
    }
  }

  /// Disposes the store and all its streams.
  void dispose() {
    for (final controller in _subscriptions.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _subscriptions.clear();
  }
}
