import 'package:flutter_test/flutter_test.dart';
import 'package:cache_nexus/cache_nexus.dart';
import 'dart:convert';

void main() {
  group('Phase 5: Security & Compression', () {
    late MemoryCacheStorage innerStorage;
    late SecureCacheStorage secureStorage;
    late SimpleEncryptor encryptor;
    late SimpleCompressor compressor;

    setUp(() {
      innerStorage = MemoryCacheStorage();
      encryptor = SimpleEncryptor('secret_key');
      compressor = SimpleCompressor();
      secureStorage = SecureCacheStorage(
        innerStorage,
        encryptor: encryptor,
        compressor: compressor,
      );
    });

    test('Data is encrypted and compressed in inner storage', () async {
      final entry = CacheEntry(
        data: 'sensitive data' * 10,
        createdAt: DateTime.now(),
      );
      await secureStorage.write('test_key', entry);

      final storedEntry = await innerStorage.read('test_key');
      expect(storedEntry, isNotNull);
      expect(storedEntry!.data, isA<String>());

      // Data in inner storage should be encrypted string, not the original map
      final encryptedData = storedEntry.data as String;
      expect(encryptedData, isNot(contains('sensitive data')));

      // Decrypt and decompress manually to verify
      final decrypted = encryptor.decrypt(encryptedData);
      final decompressed = compressor.decompress(decrypted);
      final json = jsonDecode(decompressed);
      expect(json['data'], contains('sensitive data'));
    });

    test('Data is correctly recovered via SecureCacheStorage', () async {
      final originalData = {'id': 1, 'name': 'John Doe'};
      final entry = CacheEntry(data: originalData, createdAt: DateTime.now());
      await secureStorage.write('user_1', entry);

      final recoveredEntry = await secureStorage.read('user_1');
      expect(recoveredEntry, isNotNull);
      expect(recoveredEntry!.data, equals(originalData));
    });

    test('Decryption failure returns null', () async {
      await innerStorage.write(
        'bad_key',
        CacheEntry(data: 'not_encrypted', createdAt: DateTime.now()),
      );
      final result = await secureStorage.read('bad_key');
      expect(result, isNull);
    });
  });

  group('Phase 5: Auth-Aware Cache Isolation', () {
    late CacheNexusManager manager;
    late MemoryCacheStorage memory;
    late MemoryCacheStorage persistent;

    setUp(() {
      memory = MemoryCacheStorage();
      persistent = MemoryCacheStorage();
      manager = CacheNexusManager(
        memoryStorage: memory,
        persistentStorage: persistent,
      );
    });

    test('Users have isolated cache spaces', () async {
      // User A
      manager.setContext(const CacheContext(userId: 'user_a'));
      await manager.set(key: 'profile', data: 'Profile A');

      // User B
      manager.setContext(const CacheContext(userId: 'user_b'));
      await manager.set(key: 'profile', data: 'Profile B');

      // Check User A again
      manager.setContext(const CacheContext(userId: 'user_a'));
      final profileA = await manager.get(
        key: 'profile',
        fetcher: () async => 'Fresh A',
      );
      expect(profileA, equals('Profile A'));

      // Check User B again
      manager.setContext(const CacheContext(userId: 'user_b'));
      final profileB = await manager.get(
        key: 'profile',
        fetcher: () async => 'Fresh B',
      );
      expect(profileB, equals('Profile B'));
    });

    test('Smart Invalidation only affects specific user', () async {
      const contextA = CacheContext(userId: 'user_a');
      const contextB = CacheContext(userId: 'user_b');

      manager.setContext(contextA);
      await manager.set(key: 'data', data: 'Data A');

      manager.setContext(contextB);
      await manager.set(key: 'data', data: 'Data B');

      // Invalidate User A
      await manager.invalidateByContext(contextA);

      // User A should be missing
      manager.setContext(contextA);
      expect(
        () => manager.get(
          key: 'data',
          fetcher: () async => throw Exception('Miss'),
        ),
        throwsException,
      );

      // User B should still be there
      manager.setContext(contextB);
      final dataB = await manager.get(
        key: 'data',
        fetcher: () async => 'Fresh B',
      );
      expect(dataB, equals('Data B'));
    });

    test('Role-based isolation', () async {
      const adminContext = CacheContext(userId: '123', role: 'admin');
      const userContext = CacheContext(userId: '123', role: 'user');

      manager.setContext(adminContext);
      await manager.set(key: 'settings', data: 'Admin Settings');

      manager.setContext(userContext);
      await manager.set(key: 'settings', data: 'User Settings');

      manager.setContext(adminContext);
      expect(
        await manager.get(key: 'settings', fetcher: () async => ''),
        equals('Admin Settings'),
      );

      manager.setContext(userContext);
      expect(
        await manager.get(key: 'settings', fetcher: () async => ''),
        equals('User Settings'),
      );
    });
  });
}
