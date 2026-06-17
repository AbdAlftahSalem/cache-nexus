# Installation

Smart Cache can be installed in three ways: from pub.dev, from Git, or from a local path.

---

## From pub.dev (when published)

```yaml
dependencies:
  cache_nexus: ^1.0.0
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
  print('Smart Cache installed successfully!');
}
```

---

## Platform Requirements

| Platform | Minimum Version |
|----------|-----------------|
| Flutter | >= 3.0.0 |
| Dart SDK | >= 3.11.5 |
| Android | API 16+ |
| iOS | 9.0+ |
| macOS | 10.14+ |
| Web | Chrome 84+, Firefox 80+, Safari 14+, Edge 84+ |
| Windows | 10+ |
| Linux | Ubuntu 18.04+ |

---

## Dependencies

Smart Cache includes these packages (installed automatically):

| Package | Purpose |
|---------|---------|
| `hive` | Persistent key-value storage |
| `hive_flutter` | Hive Flutter initialization |
| `connectivity_plus` | Network status monitoring |
| `path_provider` | Platform-specific storage paths |

---

## Next Steps

- [Quick Start](quick-start.md) - Get up and running in 5 minutes
- [Hello World](hello-world.md) - Minimal first cache call
- [Core Concepts](../guides/core-concepts.md) - Understand how Smart Cache works
