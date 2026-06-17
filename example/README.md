# Smart Cache Example

A Flutter app demonstrating `cache_nexus` with Dio integration.

## Features Demonstrated

- Two-tier caching (memory + Hive persistent)
- Cache policies (cacheFirst, networkFirst, etc.)
- Reactive streams with `CacheNexusBuilder`
- Dev tools overlay (floating debug button)
- Request deduplication
- Offline fallback

## Running

```bash
cd example
flutter pub get
flutter run
```
