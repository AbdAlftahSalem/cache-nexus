import 'dart:convert';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_test/flutter_test.dart';

const arabic = 'مرحبا بالعالم — عبد الفتاح 🌙 مدرسة النور';

/// The exact 1.0.0 SimpleEncryptor algorithm, to produce legacy values.
String legacyXorHex(String data, String key) {
  final out = StringBuffer();
  for (var i = 0; i < data.length; i++) {
    final c = data.codeUnitAt(i) ^ key.codeUnitAt(i % key.length);
    out.write(c.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

void main() {
  group('AesGcmEncryptor', () {
    final key = AesGcmEncryptor.generateKey();

    test('round-trips Arabic, emoji and empty strings', () {
      final e = AesGcmEncryptor(key);
      for (final s in [arabic, '', 'plain', '{"a":1}' * 500]) {
        expect(e.decrypt(e.encrypt(s)), s);
      }
    });

    test('uses a fresh nonce for every value', () {
      final e = AesGcmEncryptor(key);
      expect(e.encrypt(arabic), isNot(e.encrypt(arabic)));
    });

    test('ciphertext does not contain the plain text', () {
      final sealed = AesGcmEncryptor(key).encrypt('secret-token');
      expect(sealed, isNot(contains('secret')));
      expect(
        utf8.decode(base64Decode(sealed.substring(8)), allowMalformed: true),
        isNot(contains('secret')),
      );
    });

    test('detects tampering and wrong keys', () {
      final e = AesGcmEncryptor(key);
      final sealed = e.encrypt(arabic);
      final bytes = base64Decode(sealed.substring('aesgcm1:'.length));
      bytes[bytes.length - 1] ^= 1;
      final tampered = 'aesgcm1:${base64Encode(bytes)}';
      expect(() => e.decrypt(tampered), throwsFormatException);
      final other = AesGcmEncryptor(AesGcmEncryptor.generateKey());
      expect(() => other.decrypt(sealed), throwsFormatException);
      expect(() => e.decrypt('garbage'), throwsFormatException);
      expect(() => e.decrypt('aesgcm1:AAAA'), throwsFormatException);
    });

    test('supports AES-128/192/256 and validates the key', () {
      for (final len in [16, 24, 32]) {
        final e = AesGcmEncryptor(AesGcmEncryptor.generateKey(length: len));
        expect(e.decrypt(e.encrypt(arabic)), arabic);
      }
      expect(() => AesGcmEncryptor([1, 2, 3]), throwsArgumentError);
      final b64 = base64Encode(key);
      expect(
        AesGcmEncryptor.fromBase64(
          b64,
        ).decrypt(AesGcmEncryptor(key).encrypt('x')),
        'x',
      );
    });

    test('SecureCacheStorage treats a wrong key as a miss', () async {
      final inner = MemoryCacheStorage();
      final a = SecureCacheStorage(inner, encryptor: AesGcmEncryptor(key));
      await a.write(
        'k',
        CacheEntry<String>(data: arabic, createdAt: DateTime.now()),
      );
      expect((await a.read('k'))!.data, arabic);
      final b = SecureCacheStorage(
        inner,
        encryptor: AesGcmEncryptor(AesGcmEncryptor.generateKey()),
      );
      expect(await b.read('k'), isNull);
      expect(await a.read('missing'), isNull);
      await a.deleteByPrefix('k');
      expect(await a.read('k'), isNull);
      await a.write('z', CacheEntry<int>(data: 1, createdAt: DateTime.now()));
      await a.delete('z');
      await a.clear();
    });
  });

  // ignore_for_file: deprecated_member_use_from_same_package
  group('SimpleEncryptor (obfuscation)', () {
    test('round-trips Arabic and emoji', () {
      final e = SimpleEncryptor('مفتاح-key');
      expect(e.decrypt(e.encrypt(arabic)), arabic);
      expect(e.encrypt(arabic), startsWith('x1:'));
    });

    test('still reads values written by 1.0.0 (Latin-1 text)', () {
      final e = SimpleEncryptor('k3y');
      const json = '{"data":"hello","createdAt":"2026-01-01T00:00:00.000"}';
      expect(e.decrypt(legacyXorHex(json, 'k3y')), json);
      expect(() => e.decrypt('abc'), throwsFormatException);
    });

    test('rejects an empty key', () {
      expect(() => SimpleEncryptor(''), throwsArgumentError);
    });
  });

  group('compressors', () {
    test('GZipCompressor shrinks JSON and round-trips Arabic', () {
      const c = GZipCompressor();
      final big = jsonEncode(List.generate(200, (i) => {'id': i, 'n': arabic}));
      final packed = c.compress(big);
      expect(packed.length, lessThan(big.length ~/ 5));
      expect(c.decompress(packed), big);
    });

    test('small values are stored as they are', () {
      const c = GZipCompressor();
      expect(c.compress('hi'), 'hi');
      expect(c.decompress('hi'), 'hi');
      // Values that look like our own markers are escaped.
      for (final s in ['gz1:x', 'raw1:x', 'COMPRESSED:x']) {
        expect(c.decompress(c.compress(s)), s);
        expect(
          const SimpleCompressor().decompress(
            const SimpleCompressor().compress(s),
          ),
          s,
        );
      }
    });

    test('SimpleCompressor reads 1.0.0 values', () {
      expect(
        const SimpleCompressor().decompress('COMPRESSED:{"a":1}'),
        '{"a":1}',
      );
      expect(const SimpleCompressor().decompress('plain'), 'plain');
    });

    test('no-op implementations', () {
      expect(const NoOpCompressor().compress('a'), 'a');
      expect(const NoOpCompressor().decompress('a'), 'a');
      expect(const NoOpEncryptor().encrypt('a'), 'a');
      expect(const NoOpEncryptor().decrypt('a'), 'a');
    });
  });

  test('Arabic survives both encryptors through a full manager', () async {
    for (final enc in <CacheEncryptor>[
      AesGcmEncryptor(AesGcmEncryptor.generateKey()),
      SimpleEncryptor('k'),
    ]) {
      final storage = SecureCacheStorage(
        MemoryCacheStorage(),
        encryptor: enc,
        compressor: const GZipCompressor(),
      );
      final writer = CacheNexusManager(persistentStorage: storage);
      await writer.set<Map<String, dynamic>>(
        key: 'profile',
        data: {
          'name': arabic,
          'list': ['أ', 'ب'],
        },
      );
      // A new manager has an empty memory tier, so this reads the
      // encrypted blob.
      final reader = CacheNexusManager(persistentStorage: storage);
      final p = await reader.get<Map<String, dynamic>>(
        key: 'profile',
        fetcher: () async => throw StateError('should be cached'),
      );
      expect(p['name'], arabic, reason: enc.runtimeType.toString());
      expect(p['list'], ['أ', 'ب']);
    }
  });
}
