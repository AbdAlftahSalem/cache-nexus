import 'package:dio/dio.dart';
import '../cache_manager.dart';

class SmartCacheDioInterceptor extends Interceptor {
  final SmartCacheManager cache;

  SmartCacheDioInterceptor(this.cache);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (cache.mode == SmartCacheMode.dev) {
      options.extra['smartCacheRequestId'] = cache.recordNetworkRequest(
        url: options.uri.toString(),
        method: options.method,
        headers: _flattenHeaders(options.headers),
        body: options.data,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (cache.mode == SmartCacheMode.dev) {
      final requestId = response.requestOptions.extra['smartCacheRequestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        cache.recordNetworkResponse(
          requestId: requestId,
          url: response.requestOptions.uri.toString(),
          method: response.requestOptions.method,
          statusCode: response.statusCode ?? 0,
          headers: _flattenHeaders(response.headers.map),
          body: response.data,
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (cache.mode == SmartCacheMode.dev) {
      final requestId = err.requestOptions.extra['smartCacheRequestId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        cache.recordNetworkError(
          requestId: requestId,
          url: err.requestOptions.uri.toString(),
          method: err.requestOptions.method,
          error: err,
          headers: _flattenHeaders(err.requestOptions.headers),
        );
      }
    }
    handler.next(err);
  }

  Map<String, String> _flattenHeaders(Map<String, dynamic> headers) {
    return headers.map((k, v) => MapEntry(k, v is List ? v.join(', ') : v.toString()));
  }
}