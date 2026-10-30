# Custom Encryptor

Cache Nexus ships `AesGcmEncryptor` (AES-GCM, authenticated, random nonce per value). Use it unless you need a different cipher or key management (for example keys held in a hardware module).

---

## Built-in AES-GCM

```dart
final key = AesGcmEncryptor.generateKey(); // 32 random bytes, store it safely
final secureStorage = SecureCacheStorage(
  hiveStorage,
  encryptor: AesGcmEncryptor(key),
  compressor: const GZipCompressor(),
);
```

Keep the key in the platform keystore (e.g. `flutter_secure_storage`), see [Security & Auth](../../guides/security-auth.md).

---

## Interface

```dart
abstract class CacheEncryptor {
  String encrypt(String data);

  /// Must throw if [data] is not valid ciphertext (wrong key, tampered).
  String decrypt(String data);
}
```

Rules for a correct implementation:

1. Round-trip **any Unicode string**. Work on `utf8.encode(data)` bytes, never on `codeUnits` (UTF-16) truncated to bytes, and return text via base64.
2. Use a fresh random nonce/IV per value. A fixed IV leaks equal plaintexts and, with GCM/CTR, breaks the cipher.
3. Prefer authenticated modes (GCM, ChaCha20-Poly1305) and throw on authentication failure; `SecureCacheStorage` turns that into a cache miss.

---

## Example: wrapping another library

This example delegates to a hypothetical `MyKms` client that encrypts bytes:

```dart
import 'dart:convert';

class KmsEncryptor implements CacheEncryptor {
  KmsEncryptor(this.kms);

  final MyKms kms;

  @override
  String encrypt(String data) =>
      base64Encode(kms.seal(utf8.encode(data)));

  @override
  String decrypt(String data) =>
      utf8.decode(kms.open(base64Decode(data))); // throws if tampered
}
```

---

## Testing

```dart
void main() {
  test('round-trips Arabic and detects tampering', () {
    final encryptor = AesGcmEncryptor(AesGcmEncryptor.generateKey());
    const original = 'بيانات حساسة';

    final sealed = encryptor.encrypt(original);
    expect(encryptor.decrypt(sealed), original);
    expect(sealed, isNot(contains(original)));

    final other = AesGcmEncryptor(AesGcmEncryptor.generateKey());
    expect(() => other.decrypt(sealed), throwsFormatException);
  });
}
```

---

## Next Snippets

- [Cache Warming](cache_warming.md)
- [Testing Patterns](testing_patterns.md)
- [Request Deduplication](request_deduplication.md)
