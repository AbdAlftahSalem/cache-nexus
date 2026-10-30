import 'dart:async';
import 'dart:math';

import 'cache_event.dart';
import 'cache_stats.dart';
import 'cache_nexus_mode.dart';

/// Collects [CacheEvent]s and [CacheStats] for the dev tools.
///
/// Everything here is a no-op in [CacheNexusMode.production].
class ObservabilityManager {
  final CacheNexusMode _mode;
  final StreamController<CacheEvent> _eventController =
      StreamController<CacheEvent>.broadcast();
  CacheStats _stats = CacheStats();
  final List<CacheEvent> _recentEvents = [];
  static const int _maxRecentEvents = 100;
  static final Random _random = Random();
  int _sequence = 0;

  /// Creates a manager for [mode].
  ObservabilityManager({required CacheNexusMode mode}) : _mode = mode;

  bool get _active => _mode == CacheNexusMode.dev && !_eventController.isClosed;

  /// All events, as they happen.
  Stream<CacheEvent> get events => _eventController.stream;

  /// Aggregated statistics.
  CacheStats get stats => _stats;

  /// The most recent events (newest first, at most 100).
  List<CacheEvent> get recentEvents => List.unmodifiable(_recentEvents);

  /// Records a cache event for [key].
  void emit(
    CacheEventType type,
    String key, {
    dynamic data,
    Duration? duration,
    Object? error,
  }) {
    if (!_active) return;

    final event = CacheEvent(
      key: key,
      type: type,
      timestamp: DateTime.now(),
      data: data,
      duration: duration,
      error: error,
    );

    switch (type) {
      case CacheEventType.hit:
        _stats = _stats.copyWith(hits: _stats.hits + 1);
        break;
      case CacheEventType.miss:
        _stats = _stats.copyWith(misses: _stats.misses + 1);
        break;
      case CacheEventType.fetch:
        _stats = _stats.copyWith(fetches: _stats.fetches + 1);
        break;
      case CacheEventType.error:
        _stats = _stats.copyWith(errors: _stats.errors + 1);
        break;
      default:
        break;
    }

    _publish(event);
  }

  void _publish(CacheEvent event) {
    _eventController.add(event);
    _recentEvents.insert(0, event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeLast();
    }
  }

  /// Records an outgoing request and returns its id (empty in production).
  String recordNetworkRequest({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (!_active) return '';

    final requestId = _generateRequestId();
    _publish(
      CacheEvent(
        key: 'network:$requestId',
        type: CacheEventType.networkRequest,
        timestamp: DateTime.now(),
        url: url,
        method: method,
        requestHeaders: headers,
        requestBody: body,
        requestId: requestId,
      ),
    );
    return requestId;
  }

  /// Records a response. Status codes of 400 and above count as failed
  /// requests in [stats].
  void recordNetworkResponse({
    required String requestId,
    required String url,
    required String method,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
  }) {
    if (!_active) return;

    final ok = statusCode < 400;
    _stats = _stats.copyWith(
      totalRequests: _stats.totalRequests + 1,
      successfulRequests: _stats.successfulRequests + (ok ? 1 : 0),
      failedRequests: _stats.failedRequests + (ok ? 0 : 1),
      totalResponseTimeMs:
          _stats.totalResponseTimeMs +
          (ok ? (duration?.inMilliseconds ?? 0) : 0),
    );

    _publish(
      CacheEvent(
        key: 'network:$requestId',
        type: CacheEventType.networkResponse,
        timestamp: DateTime.now(),
        duration: duration,
        url: url,
        method: method,
        responseStatusCode: statusCode,
        responseHeaders: headers,
        responseBody: body,
        requestId: requestId,
      ),
    );
  }

  /// Records a failed request.
  void recordNetworkError({
    required String requestId,
    required String url,
    required String method,
    required Object error,
    Map<String, dynamic>? headers,
    Duration? duration,
  }) {
    if (!_active) return;

    _stats = _stats.copyWith(
      totalRequests: _stats.totalRequests + 1,
      failedRequests: _stats.failedRequests + 1,
    );

    _publish(
      CacheEvent(
        key: 'network:$requestId',
        type: CacheEventType.networkError,
        timestamp: DateTime.now(),
        duration: duration,
        error: error,
        url: url,
        method: method,
        requestHeaders: headers,
        requestId: requestId,
      ),
    );
  }

  /// Runs [request] and records it as a request/response (or error) pair.
  ///
  /// [statusCodeOf] extracts the HTTP status from the result; by default a
  /// `statusCode` property is used when the result has one, otherwise 200.
  Future<T> trackNetworkRequest<T>({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
    required Future<T> Function() request,
    int Function(T result)? statusCodeOf,
  }) async {
    final requestId = recordNetworkRequest(
      url: url,
      method: method,
      headers: headers,
      body: body,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final result = await request();
      stopwatch.stop();
      recordNetworkResponse(
        requestId: requestId,
        url: url,
        method: method,
        statusCode: statusCodeOf != null
            ? statusCodeOf(result)
            : _statusCodeOf(result),
        duration: stopwatch.elapsed,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      recordNetworkError(
        requestId: requestId,
        url: url,
        method: method,
        error: e,
        duration: stopwatch.elapsed,
      );
      rethrow;
    }
  }

  static int _statusCodeOf(Object? result) {
    try {
      final code = (result as dynamic).statusCode;
      if (code is int) return code;
    } on NoSuchMethodError {
      // No statusCode property: assume success.
    }
    return 200;
  }

  String _generateRequestId() {
    _sequence++;
    return 'req_${DateTime.now().microsecondsSinceEpoch}_${_sequence}_'
        '${_random.nextInt(10000)}';
  }

  /// Closes the event stream. Later calls are silently ignored.
  void dispose() {
    if (!_eventController.isClosed) _eventController.close();
  }
}
