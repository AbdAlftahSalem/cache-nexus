import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatus {
  static final Connectivity _connectivity = Connectivity();
  static bool? _mockOnline;
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static StreamSubscription<dynamic>? _realSubscription;

  static void setMockStatus(bool? isOnline) {
    if (_mockOnline == isOnline) return;
    _mockOnline = isOnline;
    if (isOnline != null) {
      _controller.add(isOnline);
    }
  }

  static Future<bool> get isOnline async {
    if (_mockOnline != null) return _mockOnline!;
    final result = await _connectivity.checkConnectivity();
    return result.any((element) => element != ConnectivityResult.none);
  }

  static Stream<bool> get onConnectivityChanged {
    _ensureRealSubscription();
    return _controller.stream;
  }

  static void _ensureRealSubscription() {
    if (_realSubscription != null) return;
    _realSubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final online = results.any((element) => element != ConnectivityResult.none);
        _controller.add(online);
      },
    );
  }

  static void dispose() {
    _realSubscription?.cancel();
    _realSubscription = null;
    _controller.close();
  }
}
