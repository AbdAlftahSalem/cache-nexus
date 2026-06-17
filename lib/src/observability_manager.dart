import 'dart:async';
import 'dart:math';

import 'cache_event.dart';
import 'cache_stats.dart';
import 'cache_nexus_mode.dart';

class ObservabilityManager {
  final CacheNexusMode _mode;
  final StreamController<CacheEvent> _eventController =
      StreamController<CacheEvent>.broadcast();
  CacheStats _stats = CacheStats();
  final List<CacheEvent> _recentEvents = [];
  static const int _maxRecentEvents = 100;

  ObservabilityManager({required CacheNexusMode mode}) : _mode = mode;

  Stream<CacheEvent> get events => _eventController.stream;
  CacheStats get stats => _stats;
  List<CacheEvent> get recentEvents => List.unmodifiable(_recentEvents);

  void emit(
    CacheEventType type,
    String key, {
    dynamic data,
    Duration? duration,
    Object? error,
  }) {
    if (_mode != CacheNexusMode.dev) return;

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

    _eventController.add(event);
    _addToRecentEvents(event);
  }

  void _addToRecentEvents(CacheEvent event) {
    if (_mode != CacheNexusMode.dev) return;
    _recentEvents.insert(0, event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeLast();
    }
  }

  String recordNetworkRequest({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (_mode != CacheNexusMode.dev) return '';

    final requestId = _generateRequestId();
    final event = CacheEvent(
      key: 'network:$requestId',
      type: CacheEventType.networkRequest,
      timestamp: DateTime.now(),
      url: url,
      method: method,
      requestHeaders: headers,
      requestBody: body,
      requestId: requestId,
    );
    _eventController.add(event);
    _addToRecentEvents(event);
    return requestId;
  }

  void recordNetworkResponse({
    required String requestId,
    required String url,
    required String method,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
  }) {
    if (_mode != CacheNexusMode.dev) return;

    _stats = _stats.copyWith(
      totalRequests: _stats.totalRequests + 1,
      successfulRequests: _stats.successfulRequests + 1,
      totalResponseTimeMs:
          _stats.totalResponseTimeMs + (duration?.inMilliseconds ?? 0),
    );

    final event = CacheEvent(
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
    );
    _eventController.add(event);
    _addToRecentEvents(event);
  }

  void recordNetworkError({
    required String requestId,
    required String url,
    required String method,
    required Object error,
    Map<String, dynamic>? headers,
    Duration? duration,
  }) {
    if (_mode != CacheNexusMode.dev) return;

    _stats = _stats.copyWith(
      totalRequests: _stats.totalRequests + 1,
      failedRequests: _stats.failedRequests + 1,
    );

    final event = CacheEvent(
      key: 'network:$requestId',
      type: CacheEventType.networkError,
      timestamp: DateTime.now(),
      duration: duration,
      error: error,
      url: url,
      method: method,
      requestHeaders: headers,
      requestId: requestId,
    );
    _eventController.add(event);
    _addToRecentEvents(event);
  }

  Future<T> trackNetworkRequest<T>({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
    required Future<T> Function() request,
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
        statusCode: 200,
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

  String _generateRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  void dispose() {
    _eventController.close();
  }
}
