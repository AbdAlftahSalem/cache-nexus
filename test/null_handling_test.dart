import 'package:flutter_test/flutter_test.dart';
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  test(
    'get returns null when fetcher returns null and T is nullable',
    () async {
      final cache = CacheNexusManager();
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
      final cache = CacheNexusManager();
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
      final cache = CacheNexusManager();
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
