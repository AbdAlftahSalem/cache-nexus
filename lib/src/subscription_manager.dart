import 'dart:async';

/// Manages the lifecycle of StreamControllers for cache keys.
///
/// - Creates broadcast streams on the first watch() for a key.
/// - Reuses existing streams for subsequent watchers.
/// - Disposes controllers when explicitly removed or cache is disposed.
class SubscriptionManager {
  final Map<String, StreamController<dynamic>> _controllers = {};

  /// Returns a broadcast stream for the given key.
  /// If a controller doesn't exist, it creates one.
  StreamController<dynamic> acquire(String key) {
    final existing = _controllers[key];
    if (existing != null && !existing.isClosed) {
      return existing;
    }

    final controller = StreamController<dynamic>.broadcast();
    _controllers[key] = controller;
    return controller;
  }

  /// Emits a new value to the stream associated with the key.
  /// Value can be null to indicate deletion.
  void emit(String key, dynamic value) {
    final controller = _controllers[key];
    if (controller != null && !controller.isClosed) {
      controller.add(value);
    }
  }

  /// Checks if a controller is active for a key.
  bool hasController(String key) {
    final controller = _controllers[key];
    return controller != null && !controller.isClosed;
  }

  /// Removes and closes the controller for a specific key.
  void remove(String key) {
    final controller = _controllers.remove(key);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Disposes all controllers.
  void dispose() {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
  }

  /// Returns the number of active controllers.
  int get activeControllerCount => _controllers.values
      .where((c) => !c.isClosed)
      .length;
}
