import 'dart:convert';
import 'dart:typed_data';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('down')) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final status = options.path.contains('missing') ? 404 : 200;
    return ResponseBody.fromString(
      jsonEncode({'path': options.path}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'set-cookie': ['session=abc'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioFor(CacheNexusManager cache) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeAdapter()
      ..interceptors.add(CacheNexusDioInterceptor(cache));

void main() {
  test('records request and response with redacted secrets', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    final dio = dioFor(cache);
    final res = await dio.get<dynamic>(
      '/posts',
      options: Options(headers: {'Authorization': 'Bearer secret'}),
    );
    expect(res.statusCode, 200);

    final events = cache.recentEvents.reversed.toList();
    expect(events.map((e) => e.type), [
      CacheEventType.networkRequest,
      CacheEventType.networkResponse,
    ]);
    final req = events.first;
    expect(req.url, 'https://api.test/posts');
    expect(req.requestHeaders!['Authorization'], '<redacted>');
    final resp = events.last;
    expect(resp.responseStatusCode, 200);
    expect(resp.responseHeaders!['set-cookie'], '<redacted>');
    expect(resp.requestId, req.requestId);
    expect(resp.duration, isNotNull);
    expect(cache.stats.successfulRequests, 1);
  });

  test('records HTTP errors and connection errors as failures', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    final dio = dioFor(cache);
    await expectLater(
      dio.get<dynamic>('/missing'),
      throwsA(isA<DioException>()),
    );
    await expectLater(dio.get<dynamic>('/down'), throwsA(isA<DioException>()));
    final errors = cache.recentEvents
        .where((e) => e.type == CacheEventType.networkError)
        .toList();
    expect(errors, hasLength(2));
    expect(cache.stats.failedRequests, 2);
    expect(cache.stats.totalRequests, 2);
  });

  test('custom redaction list', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    final dio = Dio()
      ..httpClientAdapter = FakeAdapter()
      ..interceptors.add(
        CacheNexusDioInterceptor(cache, redactedHeaders: const {'x-tenant'}),
      );
    await dio.get<dynamic>(
      'https://api.test/a',
      options: Options(headers: {'X-Tenant': 't1', 'Authorization': 'b'}),
    );
    final req = cache.recentEvents.last;
    expect(req.requestHeaders!['X-Tenant'], '<redacted>');
    expect(req.requestHeaders!['Authorization'], 'b');
  });

  test('does nothing in production mode', () async {
    final cache = CacheNexusManager();
    final dio = dioFor(cache);
    await dio.get<dynamic>('/posts');
    expect(cache.recentEvents, isEmpty);
    await expectLater(dio.get<dynamic>('/down'), throwsA(isA<DioException>()));
  });

  test('trackNetworkRequest reads the real status code', () async {
    final cache = CacheNexusManager(mode: CacheNexusMode.dev);
    final dio = Dio()..httpClientAdapter = FakeAdapter();
    await cache.trackNetworkRequest(
      url: 'https://api.test/missing',
      method: 'GET',
      request: () => dio.get<dynamic>(
        'https://api.test/missing',
        options: Options(validateStatus: (_) => true),
      ),
    );
    expect(cache.recentEvents.first.responseStatusCode, 404);
    expect(cache.stats.failedRequests, 1);
    await cache.trackNetworkRequest(
      url: 'u',
      method: 'GET',
      request: () async => 'plain value',
    );
    expect(cache.recentEvents.first.responseStatusCode, 200);
  });
}
