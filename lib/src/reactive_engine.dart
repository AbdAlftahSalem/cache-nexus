import 'dart:async';

/// Fans out value changes per cache key to any number of watchers.
///
/// Each watcher gets the current value once when it starts listening
/// (if `readCurrent` is given) and every later change exactly once.
class ReactiveEngine {
  final Map<String, _ControllerEntry> _controllers = {};
  bool _disposed = false;

  /// Watches [key].
  ///
  /// [readCurrent] supplies the value the new subscriber sees first; it is
  /// delivered only to that subscriber. [decode] converts emitted values to
  /// `T`; when it throws, the subscriber receives the error instead of a
  /// crash. [debounce] delays emissions until the key has been quiet for
  /// that long.
  Stream<T?> watch<T>(
    String key, {
    Future<T?> Function(String key)? readCurrent,
    Duration? debounce,
    T? Function(dynamic value)? decode,
  }) {
    final convert = decode ?? (dynamic v) => v as T?;
    Stream<T?> stream = Stream<T?>.multi((controller) {
      if (_disposed) {
        controller.close();
        return;
      }
      final entry = _acquire(key);
      var sawLiveEvent = false;

      void deliver(dynamic value) {
        try {
          controller.addSync(convert(value));
        } catch (e, st) {
          controller.addErrorSync(e, st);
        }
      }

      final sub = entry.controller.stream.listen(
        (value) {
          sawLiveEvent = true;
          deliver(value);
        },
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      controller.onCancel = sub.cancel;
      controller.onPause = sub.pause;
      controller.onResume = sub.resume;

      if (readCurrent != null) {
        Future<T?>.sync(() => readCurrent(key)).then(
          (value) {
            // A live change that arrived first is newer than this snapshot.
            if (!sawLiveEvent && !controller.isClosed) controller.add(value);
          },
          onError: (Object e, StackTrace st) {
            if (!controller.isClosed) controller.addError(e, st);
          },
        );
      }
    }, isBroadcast: true);

    if (debounce != null) {
      stream = _debounceStream(stream, debounce);
    }
    return stream;
  }

  /// Sends [value] to everyone watching [key].
  void emit(String key, dynamic value) {
    final entry = _controllers[key];
    if (entry != null && !entry.controller.isClosed) {
      entry.controller.add(value);
    }
  }

  /// Sends [value] to every watched key matching [test].
  void emitWhere(bool Function(String key) test, dynamic value) {
    for (final key in _controllers.keys.where(test).toList()) {
      emit(key, value);
    }
  }

  /// The keys that currently have at least one watcher.
  Iterable<String> get watchedKeys => _controllers.keys;

  /// Closes every stream. Later [watch] calls return closed streams.
  void dispose() {
    _disposed = true;
    for (final entry in _controllers.values) {
      if (!entry.controller.isClosed) {
        entry.controller.close();
      }
    }
    _controllers.clear();
  }

  /// The number of keys with an open controller.
  int get controllerCount => _controllers.length;

  _ControllerEntry _acquire(String key) {
    var entry = _controllers[key];
    if (entry != null && !entry.controller.isClosed) {
      return entry;
    }

    late final _ControllerEntry created;
    final controller = StreamController<dynamic>.broadcast(
      onCancel: () {
        // Close the controller once the last watcher is gone, unless a new
        // watcher arrives in the same microtask.
        Future.microtask(() {
          if (!created.controller.hasListener && !created.controller.isClosed) {
            created.controller.close();
            if (identical(_controllers[key], created)) {
              _controllers.remove(key);
            }
          }
        });
      },
    );

    created = _ControllerEntry(controller);
    _controllers[key] = created;
    return created;
  }

  Stream<T?> _debounceStream<T>(Stream<T?> stream, Duration debounce) {
    return Stream<T?>.multi((controller) {
      Timer? timer;
      final sub = stream.listen(
        (event) {
          timer?.cancel();
          timer = Timer(debounce, () {
            if (!controller.isClosed) controller.add(event);
          });
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          controller.close();
        },
      );
      controller.onCancel = () {
        timer?.cancel();
        return sub.cancel();
      };
    }, isBroadcast: true);
  }
}

class _ControllerEntry {
  final StreamController<dynamic> controller;
  _ControllerEntry(this.controller);
}
