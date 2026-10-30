import 'cache_adapter.dart';

Type _typeOf<X>() => X;

/// The outcome of [CacheTypeRegistry.decode]. Internal.
class CacheDecodeResult<T> {
  const CacheDecodeResult._(this.ok, this.value, this.error);

  /// A successful decode (the value may be `null` for nullable types).
  const CacheDecodeResult.success(T value) : this._(true, value, null);

  /// A failed decode; [error] is the adapter's exception, if any.
  const CacheDecodeResult.failure([Object? error]) : this._(false, null, error);

  /// Whether the data could be converted.
  final bool ok;

  /// The converted value. Only meaningful when [ok] is true.
  final T? value;

  /// The adapter error when [ok] is false and an adapter threw.
  final Object? error;
}

class _Codec {
  const _Codec(this.decode, [this.encode]);
  final dynamic Function(dynamic data) decode;
  final dynamic Function(dynamic value)? encode;
}

/// Knows how to turn cached data back into typed values and typed values into
/// storable data.
///
/// `CacheNexusManager` owns one; you normally interact with it through
/// `CacheNexusManager.registerAdapter`.
///
/// Out of the box it understands JSON-like data and the common collection
/// types (`List<String>`, `List<int>`, `List<double>`, `List<num>`,
/// `List<bool>`, `List<Map<String, dynamic>>`, `Map<String, dynamic>`,
/// `Map<String, String>`, `Map<String, int>`, `Map<String, double>`,
/// `Map<String, num>`, `Map<String, bool>`, `Set<String>`, `Set<int>`, and
/// `DateTime`, plus their nullable variants). Registering a
/// [CacheAdapter] for `T` adds `T`, `T?`, `List<T>` and `Map<String, T>`.
class CacheTypeRegistry {
  /// Creates a registry. [adapters] maps a type to its [CacheAdapter]; it is
  /// read live, so later additions to the map are seen.
  CacheTypeRegistry([Map<Type, dynamic>? adapters])
    : _adapters = adapters ?? <Type, dynamic>{};

  final Map<Type, dynamic> _adapters;
  final Map<Type, _Codec> _derived = {};

  /// Registers [adapter] for `T` (and `T?`, `List<T>`, `Map<String, T>`).
  void register<T>(CacheAdapter<T> adapter) {
    _adapters[T] = adapter;

    T one(dynamic e) => e is T ? e : adapter.fromData(normalize(e));
    dynamic enc(dynamic e) => e is T ? adapter.toData(e) : toStorable(e);

    _derived[_typeOf<T?>()] = _Codec(
      (d) => d == null ? null : one(d),
      (v) => v == null ? null : enc(v),
    );
    final list = _Codec(
      (d) => _asList(d).map<T>(one).toList(),
      (v) => (v as Iterable<dynamic>).map(enc).toList(),
    );
    _derived[_typeOf<List<T>>()] = list;
    _derived[_typeOf<List<T>?>()] = _nullable(list);
    final map = _Codec(
      (d) => _asMap(d).map<String, T>((k, v) => MapEntry(k, one(v))),
      (v) => (v as Map<dynamic, dynamic>).map<String, dynamic>(
        (k, e) => MapEntry(k.toString(), enc(e)),
      ),
    );
    _derived[_typeOf<Map<String, T>>()] = map;
    _derived[_typeOf<Map<String, T>?>()] = _nullable(map);
  }

  /// Whether an adapter was registered for exactly `T`.
  bool hasAdapterFor<T>() => _adapters[T] != null || _derived[T] != null;

  /// Converts cached [data] to a `T`.
  CacheDecodeResult<T> decode<T>(dynamic data) {
    if (data is T) return CacheDecodeResult<T>.success(data);
    final normalized = normalize(data);
    final adapter = _adapters[T];
    if (adapter is CacheAdapter && data != null) {
      try {
        final value = adapter.fromData(normalized);
        if (value is T) return CacheDecodeResult<T>.success(value);
      } catch (e) {
        return CacheDecodeResult<T>.failure(e);
      }
    }
    if (normalized is T) return CacheDecodeResult<T>.success(normalized);
    final codec = _derived[T] ?? _builtins[T];
    if (codec != null) {
      try {
        final value = codec.decode(normalized);
        if (value is T) return CacheDecodeResult<T>.success(value);
      } catch (e) {
        if (_derived[T] != null) return CacheDecodeResult<T>.failure(e);
      }
    }
    return CacheDecodeResult<T>.failure();
  }

  /// Converts [value] (statically a `T`) to JSON-like data for persistence.
  dynamic encode<T>(T value) {
    if (value == null) return null;
    final adapter = _adapters[T];
    if (adapter is CacheAdapter) {
      try {
        return adapter.toData(value);
      } catch (_) {
        // Fall back to the generic serializer below.
      }
    }
    final codec = _derived[T];
    if (codec?.encode != null) return codec!.encode!(value);
    final runtimeAdapter = _adapters[value.runtimeType];
    if (runtimeAdapter is CacheAdapter && !identical(runtimeAdapter, adapter)) {
      try {
        return runtimeAdapter.toData(value);
      } catch (_) {
        // Fall back to the generic serializer below.
      }
    }
    return toStorable(value);
  }

  /// Recursively converts maps to `Map<String, dynamic>` (when all keys are
  /// strings) and lists to `List<dynamic>`, as Hive returns
  /// `Map<dynamic, dynamic>` and `List<dynamic>` after a restart.
  static dynamic normalize(dynamic data) {
    if (data is Map) {
      if (data.keys.every((k) => k is String)) {
        return <String, dynamic>{
          for (final e in data.entries) e.key as String: normalize(e.value),
        };
      }
      return <dynamic, dynamic>{
        for (final e in data.entries) e.key: normalize(e.value),
      };
    }
    if (data is List) return <dynamic>[for (final e in data) normalize(e)];
    return data;
  }

  /// Converts any value to JSON-like data: primitives pass through,
  /// `DateTime` becomes an ISO-8601 string, sets become lists, map keys become
  /// strings, and objects with a `toJson()` method are converted through it.
  static dynamic toStorable(dynamic data) {
    if (data == null || data is String || data is num || data is bool) {
      return data;
    }
    if (data is DateTime) return data.toIso8601String();
    if (data is Iterable) return data.map(toStorable).toList();
    if (data is Map) {
      return data.map<dynamic, dynamic>(
        (k, v) => MapEntry(k is String ? k : k.toString(), toStorable(v)),
      );
    }
    try {
      return toStorable((data as dynamic).toJson());
    } on NoSuchMethodError {
      return data.toString();
    }
  }

  static List<dynamic> _asList(dynamic d) {
    if (d is List) return d;
    if (d is Iterable) return d.toList();
    throw FormatException('Expected a List but got ${d.runtimeType}');
  }

  static Map<String, dynamic> _asMap(dynamic d) {
    if (d is Map) {
      return d.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
    }
    throw FormatException('Expected a Map but got ${d.runtimeType}');
  }

  static _Codec _nullable(_Codec c) => _Codec(
    (d) => d == null ? null : c.decode(d),
    c.encode == null ? null : (v) => v == null ? null : c.encode!(v),
  );

  static double _toDouble(dynamic e) => (e as num).toDouble();
  static DateTime _toDate(dynamic e) =>
      e is DateTime ? e : DateTime.parse(e as String);

  static final Map<Type, _Codec> _builtins = _buildBuiltins();

  static Map<Type, _Codec> _buildBuiltins() {
    final m = <Type, _Codec>{};
    void both<X>(Type t, Type nt, dynamic Function(dynamic) f) {
      m[t] = _Codec(f);
      m[nt] = _nullable(_Codec(f));
    }

    List<E> listOf<E>(dynamic d, E Function(dynamic) f) =>
        _asList(d).map<E>(f).toList();
    Map<String, E> mapOf<E>(dynamic d, E Function(dynamic) f) =>
        _asMap(d).map<String, E>((k, v) => MapEntry(k, f(v)));

    both<void>(
      _typeOf<List<String>>(),
      _typeOf<List<String>?>(),
      (d) => listOf<String>(d, (e) => e as String),
    );
    both<void>(
      _typeOf<List<int>>(),
      _typeOf<List<int>?>(),
      (d) => listOf<int>(d, (e) => e as int),
    );
    both<void>(
      _typeOf<List<double>>(),
      _typeOf<List<double>?>(),
      (d) => listOf<double>(d, _toDouble),
    );
    both<void>(
      _typeOf<List<num>>(),
      _typeOf<List<num>?>(),
      (d) => listOf<num>(d, (e) => e as num),
    );
    both<void>(
      _typeOf<List<bool>>(),
      _typeOf<List<bool>?>(),
      (d) => listOf<bool>(d, (e) => e as bool),
    );
    both<void>(
      _typeOf<List<DateTime>>(),
      _typeOf<List<DateTime>?>(),
      (d) => listOf<DateTime>(d, _toDate),
    );
    both<void>(
      _typeOf<List<Map<String, dynamic>>>(),
      _typeOf<List<Map<String, dynamic>>?>(),
      (d) => listOf<Map<String, dynamic>>(d, (e) => _asMap(e)),
    );
    both<void>(
      _typeOf<List<List<dynamic>>>(),
      _typeOf<List<List<dynamic>>?>(),
      (d) => listOf<List<dynamic>>(d, _asList),
    );
    both<void>(
      _typeOf<Set<String>>(),
      _typeOf<Set<String>?>(),
      (d) => listOf<String>(d, (e) => e as String).toSet(),
    );
    both<void>(
      _typeOf<Set<int>>(),
      _typeOf<Set<int>?>(),
      (d) => listOf<int>(d, (e) => e as int).toSet(),
    );
    both<void>(
      _typeOf<Map<String, dynamic>>(),
      _typeOf<Map<String, dynamic>?>(),
      _asMap,
    );
    both<void>(
      _typeOf<Map<String, Object?>>(),
      _typeOf<Map<String, Object?>?>(),
      _asMap,
    );
    both<void>(
      _typeOf<Map<String, String>>(),
      _typeOf<Map<String, String>?>(),
      (d) => mapOf<String>(d, (e) => e as String),
    );
    both<void>(
      _typeOf<Map<String, int>>(),
      _typeOf<Map<String, int>?>(),
      (d) => mapOf<int>(d, (e) => e as int),
    );
    both<void>(
      _typeOf<Map<String, double>>(),
      _typeOf<Map<String, double>?>(),
      (d) => mapOf<double>(d, _toDouble),
    );
    both<void>(
      _typeOf<Map<String, num>>(),
      _typeOf<Map<String, num>?>(),
      (d) => mapOf<num>(d, (e) => e as num),
    );
    both<void>(
      _typeOf<Map<String, bool>>(),
      _typeOf<Map<String, bool>?>(),
      (d) => mapOf<bool>(d, (e) => e as bool),
    );
    both<void>(
      _typeOf<Map<String, List<dynamic>>>(),
      _typeOf<Map<String, List<dynamic>>?>(),
      (d) => mapOf<List<dynamic>>(d, _asList),
    );
    both<void>(_typeOf<double>(), _typeOf<double?>(), _toDouble);
    both<void>(_typeOf<DateTime>(), _typeOf<DateTime?>(), _toDate);
    return m;
  }
}
