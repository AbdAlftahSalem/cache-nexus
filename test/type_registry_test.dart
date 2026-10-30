import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_test/flutter_test.dart';

class Point {
  Point(this.x, this.y);
  factory Point.fromJson(Map<String, dynamic> j) =>
      Point(j['x'] as int, j['y'] as int);
  final int x;
  final int y;
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class NoJson {
  @override
  String toString() => 'NoJson!';
}

void main() {
  final hiveLikeMap = <dynamic, dynamic>{
    'a': 1,
    'nested': <dynamic, dynamic>{
      'list': <dynamic>[
        <dynamic, dynamic>{'b': 2},
      ],
    },
  };

  group('CacheTypeRegistry.decode built-ins', () {
    final r = CacheTypeRegistry();

    T ok<T>(dynamic data) {
      final res = r.decode<T>(data);
      expect(res.ok, isTrue, reason: 'decode<$T>($data)');
      return res.value as T;
    }

    test('maps are deep-normalised', () {
      final m = ok<Map<String, dynamic>>(hiveLikeMap);
      final nested = m['nested'] as Map<String, dynamic>;
      expect((nested['list'] as List).single, isA<Map<String, dynamic>>());
      expect(ok<Map<String, Object?>>(hiveLikeMap)['a'], 1);
      expect(ok<Map<String, dynamic>?>(null), isNull);
    });

    test('lists of primitives', () {
      expect(ok<List<String>>(<dynamic>['a']), ['a']);
      expect(ok<List<int>>(<dynamic>[1]), [1]);
      expect(ok<List<double>>(<dynamic>[1, 2.5]), [1.0, 2.5]);
      expect(ok<List<num>>(<dynamic>[1, 2.5]), [1, 2.5]);
      expect(ok<List<bool>>(<dynamic>[true]), [true]);
      expect(ok<List<String>?>(<dynamic>['a']), ['a']);
      expect(ok<List<DateTime>>(<dynamic>['2026-01-01T00:00:00.000']), [
        DateTime(2026),
      ]);
      expect(
        ok<List<Map<String, dynamic>>>(<dynamic>[hiveLikeMap]).single['a'],
        1,
      );
      expect(
        ok<List<List<dynamic>>>(<dynamic>[
          <dynamic>[1],
        ]),
        [
          [1],
        ],
      );
      expect(ok<Set<String>>(<dynamic>['a', 'a']), {'a'});
      expect(ok<Set<int>>(<dynamic>[1]), {1});
    });

    test('typed maps', () {
      expect(ok<Map<String, String>>(<dynamic, dynamic>{'a': 'b'}), {'a': 'b'});
      expect(ok<Map<String, int>>(<dynamic, dynamic>{'a': 1}), {'a': 1});
      expect(ok<Map<String, double>>(<dynamic, dynamic>{'a': 1}), {'a': 1.0});
      expect(ok<Map<String, num>>(<dynamic, dynamic>{'a': 1}), {'a': 1});
      expect(ok<Map<String, bool>>(<dynamic, dynamic>{'a': true}), {'a': true});
      expect(
        ok<Map<String, List<dynamic>>>(<dynamic, dynamic>{
          'a': <dynamic>[1],
        }),
        {
          'a': [1],
        },
      );
    });

    test('scalars', () {
      expect(ok<double>(3), 3.0);
      expect(ok<double?>(null), isNull);
      expect(
        ok<DateTime>('2026-10-30T08:00:00.000'),
        DateTime(2026, 10, 30, 8),
      );
      expect(ok<String?>(null), isNull);
      expect(ok<dynamic>(hiveLikeMap), same(hiveLikeMap));
    });

    test('impossible conversions fail without throwing', () {
      expect(r.decode<List<int>>(<dynamic>['x']).ok, isFalse);
      expect(r.decode<String>(null).ok, isFalse);
      expect(r.decode<Point>(<String, dynamic>{'x': 1, 'y': 2}).ok, isFalse);
      expect(r.decode<List<Point>>(<dynamic>[]).ok, isFalse);
    });
  });

  group('adapters', () {
    late CacheTypeRegistry r;
    setUp(() {
      r = CacheTypeRegistry()
        ..register<Point>(
          CacheAdapter.json(
            fromJson: Point.fromJson,
            toJson: (p) => p.toJson(),
          ),
        );
    });

    test('T, T?, List<T> and Map<String, T> are derived', () {
      expect(r.hasAdapterFor<Point>(), isTrue);
      expect(r.hasAdapterFor<List<Point>>(), isTrue);
      expect(r.decode<Point>(<dynamic, dynamic>{'x': 1, 'y': 2}).value!.y, 2);
      expect(r.decode<Point?>(null).ok, isTrue);
      expect(r.decode<Point?>(<dynamic, dynamic>{'x': 1, 'y': 2}).value!.x, 1);
      final list = r.decode<List<Point>>(<dynamic>[
        <dynamic, dynamic>{'x': 1, 'y': 2},
        Point(3, 4),
      ]);
      expect(list.value!.map((p) => p.x), [1, 3]);
      expect(r.decode<List<Point>?>(null).ok, isTrue);
      final map = r.decode<Map<String, Point>>(<dynamic, dynamic>{
        'a': <dynamic, dynamic>{'x': 5, 'y': 6},
      });
      expect(map.value!['a']!.x, 5);
      expect(r.decode<Map<String, Point>?>(null).ok, isTrue);
    });

    test('memory hits skip the adapter', () {
      final p = Point(1, 2);
      expect(r.decode<Point>(p).value, same(p));
    });

    test('a throwing adapter is a failed decode carrying the error', () {
      final res = r.decode<Point>(<dynamic, dynamic>{'x': 'oops'});
      expect(res.ok, isFalse);
      expect(res.error, isA<TypeError>());
      final listRes = r.decode<List<Point>>(<dynamic>[1]);
      expect(listRes.ok, isFalse);
      expect(listRes.error, isNotNull);
    });

    test('encode uses toData for T, List<T>, Map<String, T> and T?', () {
      expect(r.encode<Point>(Point(1, 2)), {'x': 1, 'y': 2});
      expect(r.encode<List<Point>>([Point(1, 2)]), [
        {'x': 1, 'y': 2},
      ]);
      expect(r.encode<Map<String, Point>>({'a': Point(1, 2)}), {
        'a': {'x': 1, 'y': 2},
      });
      expect(r.encode<Point?>(null), isNull);
      expect(r.encode<Point?>(Point(1, 2)), {'x': 1, 'y': 2});
      expect(r.encode<Object>(Point(7, 8)), {'x': 7, 'y': 8});
    });

    test('JsonCacheAdapter rejects non-maps', () {
      const a = JsonCacheAdapter<Point>(
        fromJson: Point.fromJson,
        toJson: _pointToJson,
      );
      expect(() => a.fromData('x'), throwsFormatException);
      expect(a.toData(Point(1, 1)), {'x': 1, 'y': 1});
    });

    test('a throwing toData falls back to the generic serializer', () {
      final r2 = CacheTypeRegistry()..register<Point>(_BadEncoder());
      expect(r2.encode<Point>(Point(1, 2)), {'x': 1, 'y': 2});
    });
  });

  group('toStorable / normalize', () {
    test('converts objects, dates, sets and non-string keys', () {
      final out = CacheTypeRegistry.toStorable({
        'p': Point(1, 2),
        'when': DateTime(2026),
        'set': {1, 2},
        3: 'int key',
        'other': NoJson(),
      });
      expect(out, {
        'p': {'x': 1, 'y': 2},
        'when': '2026-01-01T00:00:00.000',
        'set': [1, 2],
        '3': 'int key',
        'other': 'NoJson!',
      });
    });

    test('normalize keeps non-string-keyed maps as dynamic maps', () {
      final n = CacheTypeRegistry.normalize(<dynamic, dynamic>{1: 'a'});
      expect(n, isA<Map<dynamic, dynamic>>());
      expect(n, isNot(isA<Map<String, dynamic>>()));
    });
  });

  test('CacheDecodeException and CacheMissException messages', () {
    const e = CacheDecodeException(
      key: 'k',
      requestedType: 'List<Post>',
      storedType: 'List<dynamic>',
    );
    expect(e.toString(), contains('registerAdapter'));
    const e2 = CacheDecodeException(
      key: 'k',
      requestedType: 'Post',
      storedType: 'String',
      cause: 'boom',
    );
    expect(e2.toString(), contains('boom'));
    expect(
      const CacheMissException('k').toString(),
      'Exception: Cache missing or expired for key: k',
    );
  });

  test('deprecated TypeAdapter still works as an alias', () {
    // ignore: deprecated_member_use_from_same_package
    final TypeAdapter<dynamic> d = const DefaultTypeAdapter();
    expect(d.fromData(1), 1);
    expect(d.toData(2), 2);
  });
}

Map<String, dynamic> _pointToJson(Point p) => p.toJson();

class _BadEncoder extends CacheAdapter<Point> {
  @override
  Point fromData(dynamic data) => Point.fromJson(data as Map<String, dynamic>);
  @override
  dynamic toData(Point value) => throw StateError('nope');
}
