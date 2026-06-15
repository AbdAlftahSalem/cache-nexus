import 'dart:async';

class ReactiveEngine {
  final Map<String, _ControllerEntry> _controllers = {};

  Stream<T?> watch<T>(String key, {Future<T?> Function(String key)? readCurrent, Duration? debounce}) {
    final entry = _acquire(key);

    Stream<T?> stream = entry.controller.stream.map((event) => event as T?);

    if (debounce != null) {
      stream = _debounceStream(stream, debounce);
    }

    if (readCurrent != null) {
      readCurrent(key).then((value) {
        if (!entry.controller.isClosed) {
          entry.controller.add(value);
        }
      });
    }

    return stream;
  }

  void emit(String key, dynamic value) {
    final entry = _controllers[key];
    if (entry != null && !entry.controller.isClosed) {
      entry.controller.add(value);
    }
  }

  void dispose() {
    for (final entry in _controllers.values) {
      if (!entry.controller.isClosed) {
        entry.controller.close();
      }
    }
    _controllers.clear();
  }

  int get controllerCount => _controllers.length;

  _ControllerEntry _acquire(String key) {
    var entry = _controllers[key];
    if (entry != null && !entry.controller.isClosed) {
      return entry;
    }

    final controller = StreamController<dynamic>.broadcast(
      onListen: () {
        _controllers[key]?.listenerCount++;
      },
      onCancel: () {
        final e = _controllers[key];
        if (e != null) {
          e.listenerCount--;
          if (e.listenerCount == 0) {
            Future.microtask(() {
              if (e.listenerCount == 0 && !e.controller.isClosed) {
                e.controller.close();
                _controllers.remove(key);
              }
            });
          }
        }
      },
    );

    entry = _ControllerEntry(controller);
    _controllers[key] = entry;
    return entry;
  }

  Stream<T?> _debounceStream<T>(Stream<T?> stream, Duration debounce) {
    final controller = StreamController<T?>.broadcast();
    Timer? timer;

    stream.listen(
      (event) {
        timer?.cancel();
        timer = Timer(debounce, () {
          if (!controller.isClosed) {
            controller.add(event);
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        timer?.cancel();
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }
}

class _ControllerEntry {
  final StreamController<dynamic> controller;
  int listenerCount;
  _ControllerEntry(this.controller, {this.listenerCount = 0});
}
