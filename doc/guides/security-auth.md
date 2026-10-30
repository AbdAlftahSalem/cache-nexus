# Security & Auth

Cache Nexus encrypts sensitive data at rest and isolates cached data per user (and role).

---

## Security Layer

`SecureCacheStorage` wraps any `CacheStorage` and applies **compress-then-encrypt** on write and **decrypt-then-decompress** on read. Each entry is stored as one opaque string.

### Encrypting with AES-GCM (recommended)

`AesGcmEncryptor` is real authenticated encryption (AES-GCM, 256-bit key by default, a fresh random nonce for every value, 128-bit authentication tag). It handles any Unicode text, Arabic included.

The key belongs to your app. Generate it once and keep it in the platform keystore, for example with [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage):

```dart
import 'dart:convert';

import 'package:cache_nexus/cache_nexus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<CacheNexusManager> createSecureCache() async {
  const keystore = FlutterSecureStorage();
  var encryptionKey = await keystore.read(key: 'cache_key');
  if (encryptionKey == null) {
    encryptionKey = base64Encode(AesGcmEncryptor.generateKey());
    await keystore.write(key: 'cache_key', value: encryptionKey);
  }

  final hive = HiveCacheStorage(boxName: 'secure_cache');
  await hive.init();

  return CacheNexusManager(
    persistentStorage: SecureCacheStorage(
      hive,
      encryptor: AesGcmEncryptor.fromBase64(encryptionKey),
      compressor: const GZipCompressor(),
    ),
  );
}
```

What you get:

- Data on disk is unreadable without the key.
- Tampered data, data written with another key, or plain data fails authentication. `SecureCacheStorage` treats it as a **cache miss**, so the fetcher runs again.
- If the key is lost (for example the app was reinstalled and the keystore was wiped), the old cache simply misses. Nothing crashes.

Only the persistent tier is encrypted; values in memory are plain objects.

### How It Works

```
Write: entry → JSON → compress → encrypt → storage
Read:  storage → decrypt → decompress → JSON → entry
```

### SimpleEncryptor is obfuscation, not encryption

`SimpleEncryptor` XORs the UTF-8 bytes with a repeating key. Anyone who has the Hive file can recover the data. It is **deprecated** and kept only so existing apps keep working:

- Since 1.1.0 it round-trips every Unicode string, Arabic and emoji included (1.0.0 corrupted non-Latin text).
- It still reads values written by 1.0.0.

Switching an existing app from `SimpleEncryptor` to `AesGcmEncryptor` is safe: old entries fail authentication, count as misses and are re-fetched.

### Compression

`GZipCompressor` is real GZip compression (pure Dart, works on web). JSON payloads of a few hundred bytes and up usually shrink by 60-90 %. Values that would not get smaller are stored as they are.

`SimpleCompressor` compresses for real since 1.1.0 (in 1.0.0 it only added a marker) and still reads 1.0.0 values. New code should use `GZipCompressor`.

---

## Custom Encryptor

Implement `CacheEncryptor` to plug in your own cipher. `decrypt` must throw when the input is not valid; the storage then treats the entry as a miss.

```dart
abstract class CacheEncryptor {
  String encrypt(String data);
  String decrypt(String data);
}
```

See [snippets/custom_encryptor.md](../examples/snippets/custom_encryptor.md).

## Custom Compressor

```dart
abstract class CacheCompressor {
  String compress(String data);
  String decompress(String data);
}
```

---

## Auth-Aware Caching

With a `CacheContext` set, every key is prefixed with the user (and role), so different users on the same device never see each other's data.

### Set User Context

```dart
cache.setContext(const CacheContext(userId: 'user_123', role: 'admin'));
```

Keys are now stored with an unambiguous, length-prefixed scope:

```
u8:user_123|r5:admin|users
u8:user_123|r5:admin|profile
```

Without a role the scope is `u8:user_123|r|`. Because the lengths are part of the prefix, `ali` + role `admin` and a user called `ali_admin` can never collide (they could in 1.0.0, whose prefix was `userId_role_`). Data written by 1.0.0 under the old prefix is found and moved to the new key the first time it is read.

### Switch Users

```dart
// User A
cache.setContext(const CacheContext(userId: 'user_123', role: 'admin'));
final adminData = await cache.get<String>(
  key: 'secret',
  fetcher: () async => 'Admin Only',
);

// User B (isolated: different storage keys)
cache.setContext(const CacheContext(userId: 'user_456', role: 'guest'));
final guestData = await cache.get<String>(
  key: 'secret',
  fetcher: () async => 'Public Only',
);
```

### Invalidate on logout

```dart
// Everything cached for user_123, every role:
await cache.invalidateByContext(const CacheContext(userId: 'user_123'));

// Only user_123's admin data:
await cache.invalidateByContext(
  const CacheContext(userId: 'user_123', role: 'admin'),
);

// Everything for everyone:
await cache.clear();
```

Watchers of the removed keys (`watch()`, `CacheNexusBuilder`) receive `null`, so the UI stops showing the previous user's data immediately.

### Clear Context

```dart
cache.clearContext(); // back to global (unprefixed) keys; deletes nothing
```

---

## CacheContext Properties

| Property | Type | Description |
|----------|------|-------------|
| `userId` | `String` | User identifier (required) |
| `token` | `String?` | Auth token. Never part of the key |
| `role` | `String?` | Role for isolation (optional) |
| `userKeyPrefix` | `String` | `u<len>:<userId>\|` |
| `cacheKeyPrefix` | `String` | `userKeyPrefix` + `r\|` or `r<len>:<role>\|` |

---

## Best Practices

- Use `AesGcmEncryptor` for tokens and personal data; never hard-code the key.
- Call `invalidateByContext` on logout, then `clearContext`.
- Use stable, unique user ids (the backend id, not a display name).

---

## Next Steps

- [Reactive Streams](reactive-streams.md) - Watch API and widgets
- [Offline Sync](offline-sync.md) - SyncEngine for offline-first apps
- [Dev Tools](dev-tools.md) - Debug overlay and event monitoring
