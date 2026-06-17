# Custom Encryptor

Implement your own encryption for sensitive cache data.

---

## Interface

```dart
abstract class CacheEncryptor {
  String encrypt(String data);
  String decrypt(String data);
}
```

---

## Simple Example

```dart
class MyEncryptor implements CacheEncryptor {
  final String key;

  MyEncryptor(this.key);

  @override
  String encrypt(String data) {
    // Simple XOR encryption (NOT secure, just for demo)
    return String.fromCharCodes(
      data.codeUnits.map((c) => c ^ key.hashCode),
    );
  }

  @override
  String decrypt(String data) {
    // Reverse the XOR
    return String.fromCharCodes(
      data.codeUnits.map((c) => c ^ key.hashCode),
    );
  }
}
```

---

## AES Example

```dart
import 'package:encrypt/encrypt.dart' as encrypt;

class AesEncryptor implements CacheEncryptor {
  final encrypt.Key _key;
  final encrypt.IV _iv;

  AesEncryptor(String secretKey) :
    _key = encrypt.Key.fromUtf8(secretKey.padRight(32, '0').substring(0, 32)),
    _iv = encrypt.IV.fromLength(16);

  @override
  String encrypt(String data) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    return encrypter.encrypt(data, iv: _iv).base64;
  }

  @override
  String decrypt(String data) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    return encrypter.decrypt16(data, iv: _iv);
  }
}
```

---

## Usage

```dart
final secureStorage = SecureCacheStorage(
  MemoryCacheStorage(),
  encryptor: MyEncryptor('my_secret_key'),
  compressor: SimpleCompressor(),
);

final cache = CacheNexusManager(
  memoryStorage: MemoryCacheStorage(),
  persistentStorage: secureStorage,
);

// Data is automatically encrypted on write, decrypted on read
await cache.set<String>(
  key: 'credit_card',
  data: '1234-5678-9012-3456',
  ttl: const Duration(hours: 1),
);

final card = await cache.get<String>(
  key: 'credit_card',
  fetcher: () => null,
);
// card == '1234-5678-9012-3456' (decrypted automatically)
```

---

## Testing

```dart
void main() {
  test('encryption roundtrip', () {
    final encryptor = MyEncryptor('test_key');
    final original = 'sensitive data';
    
    final encrypted = encryptor.encrypt(original);
    final decrypted = encryptor.decrypt(encrypted);
    
    expect(decrypted, equals(original));
    expect(encrypted, isNot(equals(original)));
  });
}
```

---

## Next Snippets

- [Cache Warming](cache_warming.md)
- [Testing Patterns](testing_patterns.md)
- [Request Deduplication](request_deduplication.md)
