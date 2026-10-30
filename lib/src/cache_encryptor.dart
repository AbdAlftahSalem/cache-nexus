import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

/// Encrypts and decrypts the serialized cache entries stored by
/// [SecureCacheStorage](package:cache_nexus/cache_nexus.dart).
///
/// Implementations must be able to round-trip any Unicode string.
abstract class CacheEncryptor {
  /// Encrypts [data].
  String encrypt(String data);

  /// Decrypts a value produced by [encrypt]. Throws when [data] is not valid.
  String decrypt(String data);
}

/// Stores data as plain text.
class NoOpEncryptor implements CacheEncryptor {
  /// Creates the no-op encryptor.
  const NoOpEncryptor();

  @override
  String encrypt(String data) => data;

  @override
  String decrypt(String data) => data;
}

/// Real authenticated encryption: AES-GCM with a random 96-bit nonce per
/// value and a 128-bit authentication tag.
///
/// The key must come from your app (for example generated once with
/// [generateKey] and kept in the platform keystore via
/// `flutter_secure_storage`). Never hard-code it.
///
/// ```dart
/// final key = await secureStorage.read(key: 'cache_key') ??
///     base64Encode(AesGcmEncryptor.generateKey());
/// final storage = SecureCacheStorage(
///   hiveStorage,
///   encryptor: AesGcmEncryptor.fromBase64(key),
/// );
/// ```
///
/// Tampered or foreign ciphertext fails authentication; `SecureCacheStorage`
/// then treats the entry as a cache miss.
class AesGcmEncryptor implements CacheEncryptor {
  /// Creates an encryptor from a raw 16, 24 or 32 byte key
  /// (AES-128/192/256).
  AesGcmEncryptor(List<int> key) : _key = Uint8List.fromList(key) {
    if (_key.length != 16 && _key.length != 24 && _key.length != 32) {
      throw ArgumentError.value(
        key.length,
        'key',
        'AES keys must be 16, 24 or 32 bytes long',
      );
    }
  }

  /// Creates an encryptor from a base64-encoded key.
  factory AesGcmEncryptor.fromBase64(String key) =>
      AesGcmEncryptor(base64Decode(key));

  /// Generates a random key of [length] bytes (32 = AES-256) using a
  /// cryptographically secure random generator.
  static Uint8List generateKey({int length = 32}) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static const String _prefix = 'aesgcm1:';
  static const int _nonceLength = 12;
  static const int _tagBits = 128;
  static final Random _random = Random.secure();

  final Uint8List _key;

  GCMBlockCipher _cipher(bool forEncryption, Uint8List nonce) {
    return GCMBlockCipher(AESEngine())..init(
      forEncryption,
      AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)),
    );
  }

  @override
  String encrypt(String data) {
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => _random.nextInt(256)),
    );
    final sealed = _cipher(true, nonce).process(utf8.encode(data));
    final out = Uint8List(_nonceLength + sealed.length)
      ..setRange(0, _nonceLength, nonce)
      ..setRange(_nonceLength, _nonceLength + sealed.length, sealed);
    return '$_prefix${base64Encode(out)}';
  }

  @override
  String decrypt(String data) {
    if (!data.startsWith(_prefix)) {
      throw const FormatException('Not an AesGcmEncryptor value');
    }
    final bytes = base64Decode(data.substring(_prefix.length));
    if (bytes.length < _nonceLength + _tagBits ~/ 8) {
      throw const FormatException('Ciphertext too short');
    }
    final nonce = Uint8List.sublistView(bytes, 0, _nonceLength);
    final sealed = Uint8List.sublistView(bytes, _nonceLength);
    try {
      return utf8.decode(_cipher(false, nonce).process(sealed));
    } on InvalidCipherTextException {
      throw const FormatException(
        'Authentication failed: wrong key or tampered data',
      );
    }
  }
}

/// **Obfuscation only, not encryption.** XORs the UTF-8 bytes with a
/// repeating key and base64-encodes the result.
///
/// It keeps casual readers from seeing plain text in the Hive file, but
/// anyone with the file can recover the data. Use [AesGcmEncryptor] for real
/// protection.
///
/// Since 1.1.0 it handles every Unicode string (Arabic included). Values
/// written by 1.0.x (hex format) are still readable.
@Deprecated(
  'SimpleEncryptor is XOR obfuscation, not encryption. Use AesGcmEncryptor.',
)
class SimpleEncryptor implements CacheEncryptor {
  /// The obfuscation key. Must not be empty.
  final String key;

  /// Creates an obfuscator with [key].
  SimpleEncryptor(this.key) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', 'must not be empty');
  }

  static const String _prefix = 'x1:';

  List<int> _xor(List<int> bytes, List<int> keyBytes) => [
    for (var i = 0; i < bytes.length; i++)
      bytes[i] ^ keyBytes[i % keyBytes.length],
  ];

  @override
  String encrypt(String data) {
    final bytes = _xor(utf8.encode(data), utf8.encode(key));
    return '$_prefix${base64Encode(bytes)}';
  }

  @override
  String decrypt(String data) {
    if (data.startsWith(_prefix)) {
      final bytes = base64Decode(data.substring(_prefix.length));
      return utf8.decode(_xor(bytes, utf8.encode(key)));
    }
    return _decryptLegacy(data);
  }

  /// Reads the 1.0.x format: hex pairs of code units XOR the key's code
  /// units (only ever correct for Latin-1 text).
  String _decryptLegacy(String data) {
    if (data.length.isOdd) {
      throw const FormatException('Invalid SimpleEncryptor value');
    }
    final bytes = <int>[];
    for (var i = 0; i < data.length; i += 2) {
      bytes.add(int.parse(data.substring(i, i + 2), radix: 16));
    }
    return String.fromCharCodes(_xor(bytes, key.codeUnits));
  }
}
