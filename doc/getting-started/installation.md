# Installation

Cache Nexus can be installed in three ways: from pub.dev, from Git, or from a local path.

---

## From pub.dev

```yaml
dependencies:
  cache_nexus: ^1.1.0
```

Then run:

```bash
flutter pub get
```

---

## From Git

```yaml
dependencies:
  cache_nexus:
    git:
      url: https://github.com/AbdAlftahSalem/cache-nexus.git
      ref: main
```

Then run:

```bash
flutter pub get
```

### Specific version or branch

```yaml
dependencies:
  cache_nexus:
    git:
      url: https://github.com/AbdAlftahSalem/cache-nexus.git
      ref: v1.0.0  # or any branch/tag
```

---

## From local path

```yaml
dependencies:
  cache_nexus:
    path: ../cache_nexus
```

This is useful for development or when using a custom fork.

---

## Verify Installation

After installation, verify it works:

```dart
import 'package:cache_nexus/cache_nexus.dart';

void main() {
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
  );
  print('Cache Nexus installed successfully!');
}
```

---

## Platform Requirements

| Requirement | Version |
|-------------|---------|
| Flutter | >= 3.41.0 |
| Dart SDK | >= 3.11.0 |

Runs on Android, iOS, macOS, Windows, Linux and web (including WebAssembly builds). Minimum OS versions are those of your Flutter version; Cache Nexus adds none of its own.

---

## Dependencies

Cache Nexus includes these packages (installed automatically):

| Package | Purpose |
|---------|---------|
| `hive_ce` / `hive_ce_flutter` | Persistent key-value storage (Hive Community Edition) |
| `connectivity_plus` | Network status monitoring |
| `dio` | Optional `CacheNexusDioInterceptor` for the dev tools |
| `pointycastle` | AES-GCM for `AesGcmEncryptor` |
| `archive` | GZip for `GZipCompressor` |
| `crypto` | SHA-256 for long Hive keys |

---

## Next Steps

- [Quick Start](quick-start.md) - Get up and running in 5 minutes
- [Hello World](hello-world.md) - Minimal first cache call
- [Core Concepts](../guides/core-concepts.md) - Understand how Cache Nexus works
