import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';

void main() {
  test(
    'get returns null when fetcher returns null and T is nullable',
    () async {
      final cache = SmartCacheManager();
      final result = await cache.get<String?>(
        key: 'test',
        fetcher: () async => null,
      );
      expect(result, isNull);
    },
  );

  test(
    'get returns null on cache miss with cacheOnly policy and T is nullable',
    () async {
      final cache = SmartCacheManager();
      final result = await cache.get<String?>(
        key: 'test',
        fetcher: () async => 'data',
        policy: CachePolicy.cacheOnly,
      );
      expect(result, isNull);
    },
  );

  test(
    'get throws on cache miss with cacheOnly policy and T is non-nullable',
    () async {
      final cache = SmartCacheManager();
      expect(
        () => cache.get<String>(
          key: 'test',
          fetcher: () async => 'data',
          policy: CachePolicy.cacheOnly,
        ),
        throwsException,
      );
    },
  );
}
