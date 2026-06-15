import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cache/smart_cache.dart';
import 'dart:convert';

void main() {
  late MemoryCacheStorage innerStorage;
  late SecureCacheStorage secureStorage;
  late SimpleEncryptor encryptor;
  late SimpleCompressor compressor;

  setUp(() {
    innerStorage = MemoryCacheStorage();
    encryptor = SimpleEncryptor('test_secret_key');
    compressor = SimpleCompressor();
    secureStorage = SecureCacheStorage(
      innerStorage,
      encryptor: encryptor,
      compressor: compressor,
    );
  });

  test('encrypted data stored in Hive is not plaintext', () async {
    final entry = CacheEntry(
      data: 'sensitive data that must be encrypted',
      createdAt: DateTime.now(),
    );
    await secureStorage.write('secret', entry);

    final raw = await innerStorage.read('secret');
    expect(raw, isNotNull);
    final rawData = raw!.data as String;
    expect(rawData, isNot(contains('sensitive data')));
  });

  test('SecureCacheStorage roundtrip recovers data', () async {
    final original = {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'};
    final entry = CacheEntry(data: original, createdAt: DateTime.now());
    await secureStorage.write('user', entry);

    final recovered = await secureStorage.read('user');
    expect(recovered, isNotNull);
    expect(recovered!.data, equals(original));
  });

  test('decryption failure returns null', () async {
    await innerStorage.write(
      'bad_key',
      CacheEntry(data: 'not_encrypted', createdAt: DateTime.now()),
    );
    final result = await secureStorage.read('bad_key');
    expect(result, isNull);
  });

  test('encrypt+compress pipeline works', () async {
    final entry = CacheEntry(
      data: 'data ' * 50,
      createdAt: DateTime.now(),
    );
    await secureStorage.write('pipeline', entry);

    final raw = await innerStorage.read('pipeline');
    expect(raw, isNotNull);
    final rawData = raw!.data as String;
    final decrypted = encryptor.decrypt(rawData);
    final decompressed = compressor.decompress(decrypted);
    final json = jsonDecode(decompressed);
    expect(json['data'], contains('data'));
  });
}
