import 'cache_adapter.dart';

/// The 1.0 name of [CacheAdapter].
///
/// It clashes with Hive's own `TypeAdapter` in any file that imports both
/// packages. Use [CacheAdapter] instead; this alias will be removed in 2.0.0.
@Deprecated(
  'Use CacheAdapter instead. TypeAdapter clashes with Hive\'s TypeAdapter '
  'and will be removed in 2.0.0.',
)
typedef TypeAdapter<T> = CacheAdapter<T>;

/// An adapter that returns data unchanged.
class DefaultTypeAdapter implements CacheAdapter<dynamic> {
  /// Creates the identity adapter.
  const DefaultTypeAdapter();

  @override
  dynamic fromData(dynamic data) => data;

  @override
  dynamic toData(dynamic value) => value;
}
