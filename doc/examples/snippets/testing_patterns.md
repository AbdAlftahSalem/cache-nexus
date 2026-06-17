# Testing Patterns

Unit and widget testing patterns for Smart Cache.

---

## Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cache_nexus/cache_nexus.dart';

late CacheNexusManager cache;

setUp(() {
  cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    mode: CacheNexusMode.dev,
  );
});

tearDown(() async {
  await cache.clear();
  await cache.dispose();
});
```

---

## Unit Testing

### Test Basic Operations

```dart
void main() {
  late CacheNexusManager cache;

  setUp(() {
    cache = CacheNexusManager(
      memoryStorage: MemoryCacheStorage(),
    );
  });

  tearDown(() async {
    await cache.clear();
    await cache.dispose();
  });

  test('set and get', () async {
    await cache.set<String>(key: 'test', data: 'hello');
    final result = await cache.get<String>(
      key: 'test',
      fetcher: () => null,
    );
    expect(result, equals('hello'));
  });

  test('get with fetcher on miss', () async {
    final result = await cache.get<String>(
      key: 'test',
      fetcher: () async => 'fetched',
    );
    expect(result, equals('fetched'));
  });

  test('delete', () async {
    await cache.set<String>(key: 'test', data: 'hello');
    await cache.delete( 'test');
    final result = await cache.get<String>(
      key: 'test',
      fetcher: () => null,
    );
    expect(result, isNull);
  });

  test('clear', () async {
    await cache.set<String>(key: 'a', data: '1');
    await cache.set<String>(key: 'b', data: '2');
    await cache.clear();
    final a = await cache.get<String>(key: 'a', fetcher: () => null);
    final b = await cache.get<String>(key: 'b', fetcher: () => null);
    expect(a, isNull);
    expect(b, isNull);
  });
}
```

---

## Test TTL Expiration

```dart
test('expired entry returns null', () async {
  await cache.set<String>(
    key: 'test',
    data: 'hello',
    ttl: const Duration(milliseconds: 1),
  );

  // Wait for expiration
  await Future.delayed(const Duration(milliseconds: 10));

  final result = await cache.get<String>(
    key: 'test',
    fetcher: () => null,
  );
  expect(result, isNull);
});
```

---

## Test Cache Policies

```dart
test('cacheFirst returns cached data', () async {
  await cache.set<String>(key: 'test', data: 'cached');

  final result = await cache.get<String>(
    key: 'test',
    fetcher: () async => 'fetched',
    policy: CachePolicy.cacheFirst,
  );

  expect(result, equals('cached'));
});

test('networkFirst fetches fresh data', () async {
  await cache.set<String>(key: 'test', data: 'cached');

  final result = await cache.get<String>(
    key: 'test',
    fetcher: () async => 'fetched',
    policy: CachePolicy.networkFirst,
  );

  expect(result, equals('fetched'));
});
```

---

## Test Auth Isolation

```dart
test('user isolation', () async {
  // User A
  cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
  await cache.set<String>(key: 'data', data: 'admin_data');

  // User B
  cache.setContext(CacheContext(userId: 'user_2', role: 'guest'));
  final result = await cache.get<String>(
    key: 'data',
    fetcher: () async => 'guest_data',
  );

  expect(result, equals('guest_data'));

  // Switch back to User A
  cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
  final adminData = await cache.get<String>(
    key: 'data',
    fetcher: () => null,
  );

  expect(adminData, equals('admin_data'));
});
```

---

## Test Reactive Streams

```dart
test('watch notifies on update', () async {
  final completer = Completer<String?>();

  cache.watch<String>('test').listen((data) {
    if (!completer.isCompleted) {
      completer.complete(data);
    }
  });

  await cache.set<String>(key: 'test', data: 'hello');

  final result = await completer.future;
  expect(result, equals('hello'));
});
```

---

## Widget Testing

```dart
testWidgets('CacheNexusBuilder rebuilds', (tester) async {
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: CacheNexusBuilder<String>(
        cache: cache,
        cacheKey: 'test',
        builder: (context, data) {
          return Text(data ?? 'No data');
        },
      ),
    ),
  );

  // Initial state
  expect(find.text('No data'), findsOneWidget);

  // Update cache
  await cache.set<String>(key: 'test', data: 'Hello');
  await tester.pump();

  // Rebuilt with data
  expect(find.text('Hello'), findsOneWidget);
});
```

---

## Mocking

```dart
class MockCacheNexusManager extends Mock implements CacheNexusManager {}

void main() {
  test('service uses cache', () async {
    final cache = MockCacheNexusManager();
    when(() => cache.get<String>(
      key: any(named: 'key'),
      fetcher: any(named: 'fetcher'),
    )).thenAnswer((_) async => 'mocked_data');

    final service = MyService(cache: cache);
    final result = await service.getData();

    expect(result, equals('mocked_data'));
    verify(() => cache.get<String>(
      key: 'data',
      fetcher: any(named: 'fetcher'),
    )).called(1);
  });
}
```

---

## Next Snippets

- [Request Deduplication](request_deduplication.md)
- [Cache Invalidation](cache_invalidation.md)
- [Stream Debounce](stream_debounce.md)
