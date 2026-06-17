import 'package:flutter_test/flutter_test.dart';
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  late CacheNexusManager cache;
  late MemoryCacheStorage storage;

  setUp(() {
    storage = MemoryCacheStorage();
    cache = CacheNexusManager(memoryStorage: storage);
  });

  tearDown(() {
    cache.dispose();
  });

  test('watch emits initial cached value', () async {
    await cache.set(key: 'test', data: 'initial');

    final values = <String?>[];
    final sub = cache.watch<String>('test').listen((v) => values.add(v));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(values, ['initial']);
    await sub.cancel();
  });

  test('watch emits updates on set', () async {
    final values = <String?>[];
    final sub = cache.watch<String>('test').listen((v) => values.add(v));
    await Future.delayed(const Duration(milliseconds: 10));

    await cache.set(key: 'test', data: 'first');
    await Future.delayed(const Duration(milliseconds: 5));
    await cache.set(key: 'test', data: 'second');
    await Future.delayed(const Duration(milliseconds: 5));

    expect(values, [null, 'first', 'second']);
    await sub.cancel();
  });

  test('CacheNexusBuilder rebuilds on change', () async {
    await cache.set(key: 'test', data: 'initial');

    final values = <String?>[];
    final sub = cache.watch<String>('test').listen((v) => values.add(v));
    await Future.delayed(const Duration(milliseconds: 10));

    await cache.set(key: 'test', data: 'updated');
    await Future.delayed(const Duration(milliseconds: 10));

    expect(values, contains('updated'));
    await sub.cancel();
  });

  test('watch debounce suppresses rapid updates', () async {
    final values = <String?>[];
    final sub = cache
        .watch<String>('test', debounce: const Duration(milliseconds: 100))
        .listen((v) => values.add(v));

    await Future.delayed(const Duration(milliseconds: 10));
    await cache.set(key: 'test', data: 'a');
    await Future.delayed(const Duration(milliseconds: 20));
    await cache.set(key: 'test', data: 'b');
    await Future.delayed(const Duration(milliseconds: 20));
    await cache.set(key: 'test', data: 'c');

    await Future.delayed(const Duration(milliseconds: 200));

    expect(values, contains('c'));
    await sub.cancel();
  });

  test('watch emits null after delete', () async {
    await cache.set(key: 'test', data: 'value');

    final values = <String?>[];
    final sub = cache.watch<String?>('test').listen((v) => values.add(v));
    await Future.delayed(const Duration(milliseconds: 10));

    await cache.delete('test');
    await Future.delayed(const Duration(milliseconds: 10));

    expect(values, contains(null));
    expect(values, contains('value'));
    await sub.cancel();
  });
}
