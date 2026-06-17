import 'package:dio/dio.dart';
import '../cache_manager.dart';
import '../smart_cache_mode.dart';

class SmartCacheDioInterceptor extends Interceptor {
  final SmartCacheManager cache;

  SmartCacheDioInterceptor(this.cache);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (cache.mode == SmartCacheMode.dev) {
      final stopwatch = Stopwatch()..start();
      final requestId = cache.recordNetworkRequest(
        url: options.uri.toString(),
        method: options.method,
        headers: _flattenHeaders(options.headers),
        body: options.data,
      );
      options.extra['smartCacheRequestId'] = requestId;
      options.extra['smartCacheStopwatch'] = stopwatch;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (cache.mode == SmartCacheMode.dev) {
      final requestId =
          response.requestOptions.extra['smartCacheRequestId'] as String?;
      final stopwatch =
          response.requestOptions.extra['smartCacheStopwatch'] as Stopwatch?;
      if (requestId != null && requestId.isNotEmpty) {
        stopwatch?.stop();
        cache.recordNetworkResponse(
          requestId: requestId,
          url: response.requestOptions.uri.toString(),
          method: response.requestOptions.method,
          statusCode: response.statusCode ?? 0,
          headers: _flattenHeaders(response.headers.map),
          body: response.data,
          duration: stopwatch?.elapsed,
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (cache.mode == SmartCacheMode.dev) {
      final requestId =
          err.requestOptions.extra['smartCacheRequestId'] as String?;
      final stopwatch =
          err.requestOptions.extra['smartCacheStopwatch'] as Stopwatch?;
      if (requestId != null && requestId.isNotEmpty) {
        stopwatch?.stop();
        cache.recordNetworkError(
          requestId: requestId,
          url: err.requestOptions.uri.toString(),
          method: err.requestOptions.method,
          error: err,
          headers: _flattenHeaders(err.requestOptions.headers),
          duration: stopwatch?.elapsed,
        );
      }
    }
    handler.next(err);
  }

  Map<String, String> _flattenHeaders(Map<String, dynamic> headers) {
    return headers.map(
      (k, v) => MapEntry(k, v is List ? v.join(', ') : v.toString()),
    );
  }
}
