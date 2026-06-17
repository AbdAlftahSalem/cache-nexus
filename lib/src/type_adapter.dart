abstract class TypeAdapter<T> {
  T fromData(dynamic data);
  dynamic toData(T value);
}

class DefaultTypeAdapter implements TypeAdapter<dynamic> {
  const DefaultTypeAdapter();

  @override
  dynamic fromData(dynamic data) => data;

  @override
  dynamic toData(dynamic value) => value;
}
