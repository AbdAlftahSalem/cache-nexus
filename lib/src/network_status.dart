import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity information used by the policies and the sync engine.
///
/// In tests, call [setMockStatus] to force online/offline; pass `null` to go
/// back to the real platform status.
class NetworkStatus {
  NetworkStatus._();

  static Connectivity? _connectivity;
  static bool? _mockOnline;
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static StreamSubscription<dynamic>? _realSubscription;

  static Connectivity get _platform => _connectivity ??= Connectivity();

  /// Forces the status (and notifies listeners). `null` clears the override.
  static void setMockStatus(bool? isOnline) {
    if (_mockOnline == isOnline) return;
    _mockOnline = isOnline;
    if (isOnline != null) {
      _controller.add(isOnline);
    }
  }

  /// Whether the device currently has a network connection.
  ///
  /// When the platform cannot be queried (for example in a plain Dart test),
  /// the device is assumed to be online.
  static Future<bool> get isOnline async {
    final mock = _mockOnline;
    if (mock != null) return mock;
    try {
      final result = await _platform.checkConnectivity();
      return result.any((element) => element != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Emits `true`/`false` whenever connectivity changes.
  static Stream<bool> get onConnectivityChanged {
    _ensureRealSubscription();
    return _controller.stream;
  }

  static void _ensureRealSubscription() {
    if (_realSubscription != null) return;
    // Errors raised while subscribing (no platform binding in plain Dart
    // tests, missing plugin) are reported asynchronously, so a guarded zone
    // is used instead of try/catch. Connectivity then simply never changes.
    runZonedGuarded(() {
      _realSubscription = _platform.onConnectivityChanged.listen((results) {
        final online = results.any(
          (element) => element != ConnectivityResult.none,
        );
        if (_mockOnline == null) _controller.add(online);
      }, onError: (Object _) {});
    }, (error, stack) {});
  }

  /// Stops listening to the platform. The shared stream stays usable, so
  /// existing and future listeners keep working.
  static void dispose() {
    _realSubscription?.cancel();
    _realSubscription = null;
  }
}
