import 'dart:async';

import 'package:smart_cache/smart_cache.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 6: Reactive Cache System', () {
    late SmartCacheManager cache;
    late MemoryCacheStorage storage;

    setUp(() {
      storage = MemoryCacheStorage();
      cache = SmartCacheManager(memoryStorage: storage);
    });

    tearDown(() {
      cache.dispose();
    });

    // ----------------------------------------------------------------------
    // Watch API Tests
    // ----------------------------------------------------------------------
    group('Watch API', () {
      test('watch emits initial value when key is already cached', () async {
        await cache.set(key: 'test', data: 'initial');

        final values = <String?>[];
        final subscription = cache.watch<String>('test').listen((value) {
          values.add(value);
        });

        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(values, ['initial']);

        await subscription.cancel();
      });

      test('watch emits updates when set() is called', () async {
        final values = <String?>[];
        final subscription = cache.watch<String>('test').listen((value) {
          values.add(value);
        });

        // Wait for seed (null for missing key)
        await Future<void>.delayed(Duration(milliseconds: 10));

        await cache.set(key: 'test', data: 'first');
        await Future<void>.delayed(Duration(milliseconds: 5));
        await cache.set(key: 'test', data: 'second');
        await Future<void>.delayed(Duration(milliseconds: 5));

        expect(values, [null, 'first', 'second']);

        await subscription.cancel();
      });

      test('watch emits null after delete', () async {
        await cache.set(key: 'test', data: 'value');

        final values = <String?>[];
        final subscription = cache.watch<String?>('test').listen((value) {
          values.add(value);
        });

        // Wait for seed
        await Future<void>.delayed(Duration(milliseconds: 10));

        await cache.delete('test');
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(values, contains(null));
        expect(values, contains('value'));

        await subscription.cancel();
      });

      test('watch supports multiple listeners on the same key', () async {
        await cache.set(key: 'test', data: 'initial');

        final values1 = <String?>[];
        final values2 = <String?>[];

        final sub1 = cache.watch<String>('test').listen((v) => values1.add(v));
        final sub2 = cache.watch<String>('test').listen((v) => values2.add(v));

        // Wait for both seeds to arrive
        await Future<void>.delayed(Duration(milliseconds: 20));

        await cache.set(key: 'test', data: 'updated');
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(values1, contains('initial'));
        expect(values1, contains('updated'));
        expect(values2, contains('initial'));
        expect(values2, contains('updated'));

        await sub1.cancel();
        await sub2.cancel();
      });

      test('watch with debounce prevents rapid emissions', () async {
        final values = <String?>[];
        final subscription = cache
            .watch<String>('test', debounce: Duration(milliseconds: 100))
            .listen((value) {
          values.add(value);
        });

        await Future<void>.delayed(Duration(milliseconds: 10));

        await cache.set(key: 'test', data: 'a');
        await Future<void>.delayed(Duration(milliseconds: 20));
        await cache.set(key: 'test', data: 'b');
        await Future<void>.delayed(Duration(milliseconds: 20));
        await cache.set(key: 'test', data: 'c');

        // Wait for debounce to settle
        await Future<void>.delayed(Duration(milliseconds: 200));

        // Should have seed + debounced final value
        expect(values, contains('c'));

        await subscription.cancel();
      });
    });

    // ----------------------------------------------------------------------
    // Memory Leak Prevention Tests
    // ----------------------------------------------------------------------
    group('Memory Management', () {
      test('stream controller auto-closes after last listener unsubscribes', () async {
        final sub = cache.watch<String>('test').listen((_) {});
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(cache.reactiveEngine.controllerCount, 1);

        await sub.cancel();
        // Give time for microtask cleanup
        await Future<void>.delayed(Duration(milliseconds: 50));

        // Controller should be auto-closed and removed
        expect(cache.reactiveEngine.controllerCount, 0);
      });

      test('no memory leaks after 1000 watch/cancel cycles', () async {
        for (var i = 0; i < 1000; i++) {
          final sub = cache.watch<String>('key_$i').listen((_) {});
          await sub.cancel();
        }
        expect(cache.reactiveEngine.controllerCount, 0);
      });

      test('no memory leaks after dispose', () async {
        for (var i = 0; i < 10; i++) {
          cache.watch<String>('test$i').listen((_) {});
          await Future<void>.delayed(Duration(milliseconds: 5));
        }

        cache.dispose();
        await Future<void>.delayed(Duration(milliseconds: 50));
        expect(cache.reactiveEngine.controllerCount, 0);
      });
    });

    // ----------------------------------------------------------------------
    // Backward Compatibility Tests
    // ----------------------------------------------------------------------
    group('Backward Compatibility', () {
      test('existing get/set API still works with reactive layer', () async {
        await cache.set(key: 'compat', data: 'value');

        final result = await cache.get(
          key: 'compat',
          fetcher: () async => 'fetched',
        );

        expect(result, 'value');

        // Verify reactive layer still works
        final values = <String?>[];
        final sub = cache.watch<String>('compat').listen((v) => values.add(v));
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(values, contains('value'));
        await sub.cancel();
      });
    });

    // ----------------------------------------------------------------------
    // Edge Case Tests
    // ----------------------------------------------------------------------
    group('Edge Cases', () {
      test('missing key emits null seed', () async {
        final values = <String?>[];
        final sub = cache.watch<String>('missing').listen((v) => values.add(v));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Should emit null for missing key
        expect(values, [null]);

        await sub.cancel();
      });

      test('watch on non-existent key then set emits both', () async {
        final values = <String?>[];
        final sub = cache.watch<String>('new').listen((v) => values.add(v));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Wait for seed
        expect(values, [null]);

        await cache.set(key: 'new', data: 'created');
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(values, [null, 'created']);

        await sub.cancel();
      });
    });
  });
}
