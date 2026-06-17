# Testing

Unit, widget, and integration testing patterns for Smart Cache.

---

## Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';

late SmartCacheManager cache;

setUp(() {
  cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    mode: SmartCacheMode.dev,
  );
});

tearDown(() async {
  await cache.clear();
  await cache.dispose();
});
```

---

## Unit Testing

### Basic Operations

```dart
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
```

### TTL Expiration

```dart
test('expired entry returns null', () async {
  await cache.set<String>(
    key: 'test',
    data: 'hello',
    ttl: const Duration(milliseconds: 1),
  );

  await Future.delayed(const Duration(milliseconds: 10));

  final result = await cache.get<String>(
    key: 'test',
    fetcher: () => null,
  );
  expect(result, isNull);
});
```

### Cache Policies

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

### Auth Isolation

```dart
test('user isolation', () async {
  cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
  await cache.set<String>(key: 'data', data: 'admin_data');

  cache.setContext(CacheContext(userId: 'user_2', role: 'guest'));
  final result = await cache.get<String>(
    key: 'data',
    fetcher: () async => 'guest_data',
  );

  expect(result, equals('guest_data'));

  cache.setContext(CacheContext(userId: 'user_1', role: 'admin'));
  final adminData = await cache.get<String>(
    key: 'data',
    fetcher: () => null,
  );

  expect(adminData, equals('admin_data'));
});
```

### Reactive Streams

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
testWidgets('SmartCacheBuilder rebuilds', (tester) async {
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: SmartCacheBuilder<String>(
        cache: cache,
        cacheKey: 'test',
        builder: (context, data) {
          return Text(data ?? 'No data');
        },
      ),
    ),
  );

  expect(find.text('No data'), findsOneWidget);

  await cache.set<String>(key: 'test', data: 'Hello');
  await tester.pump();

  expect(find.text('Hello'), findsOneWidget);
});
```

---

## Mocking

```dart
class MockSmartCacheManager extends Mock implements SmartCacheManager {}

void main() {
  test('service uses cache', () async {
    final cache = MockSmartCacheManager();
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

## Integration Testing

```dart
testWidgets('full cache flow', (tester) async {
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SmartCacheBuilder<String>(
          cache: cache,
          cacheKey: 'counter',
          builder: (context, data) {
            return Text(data ?? '0');
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final current = await cache.get<String>(
              key: 'counter',
              fetcher: () => '0',
            );
            final next = int.parse(current!) + 1;
            await cache.set<String>(key: 'counter', data: '$next');
          },
          child: const Icon(Icons.add),
        ),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();

  expect(find.text('1'), findsOneWidget);
});
```

---

## Best Practices

### 1. Test All Policies

```dart
for (final policy in CachePolicy.values) {
  test('policy $policy works', () async {
    final result = await cache.get<String>(
      key: 'test',
      fetcher: () async => 'data',
      policy: policy,
    );
    expect(result, isNotNull);
  });
}
```

### 2. Test Error Cases

```dart
test('handles fetcher error gracefully', () async {
  final result = await cache.get<String>(
    key: 'test',
    fetcher: () async => throw Exception('API error'),
  );
  expect(result, isNull);
});
```

### 3. Test Cleanup

```dart
test('dispose cleans up resources', () async {
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
  );
  
  await cache.set<String>(key: 'test', data: 'hello');
  await cache.dispose();
  
  // Should not throw
  expect(cache.events, isDone);
});
```

---

## Next

- [Performance](performance.md)
- [Migration](migration.md)
