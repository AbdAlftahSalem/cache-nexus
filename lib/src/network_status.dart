import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatus {
  static Connectivity _connectivity = Connectivity();
  static bool? _mockOnline;

  static void setMockStatus(bool? isOnline) {
    _mockOnline = isOnline;
  }

  static Future<bool> get isOnline async {
    if (_mockOnline != null) return _mockOnline!;
    final result = await _connectivity.checkConnectivity();
    return result.any((element) => element != ConnectivityResult.none);
  }

  static Stream<bool> get onConnectivityChanged {
    if (_mockOnline != null) return Stream.value(_mockOnline!);
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((element) => element != ConnectivityResult.none),
    );
  }
}
