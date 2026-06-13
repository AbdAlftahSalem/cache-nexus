# Smart Cache

> 🚀 A powerful Offline-First, Debuggable Data Layer for Flutter applications.

---

# Vision

Smart Cache is not just a caching library.

It is a full **data orchestration layer** between UI, API, and local storage, designed to simplify how Flutter apps handle:

* Remote data
* Local caching
* Offline scenarios
* Request lifecycle debugging

The goal is to eliminate repetitive data-layer logic in every project.

---

# Core Philosophy

Developers should NOT manually handle:

* API state management
* Cache logic
* Offline fallback
* Request deduplication
* Debugging network behavior

Smart Cache handles all of that automatically.

---

# ✨ Key Features

## 1. Smart Caching Engine

* TTL-based caching
* Memory-first architecture
* Fetch fallback system
* Automatic cache expiration

---

## 2. Request Deduplication

Prevents duplicate API calls:

```text
Multiple Widgets
     ↓
Single Network Request
     ↓
Shared Response
```

---

## 3. Offline Support (Future Phase)

* Return cached data when offline
* Graceful failure handling
* Optional background sync

---

## 4. Cache Policies (Future Phase)

* cacheFirst
* networkFirst
* cacheOnly
* networkOnly
* staleWhileRevalidate

---

# 🧠 Dev Mode (NEW FEATURE)

Smart Cache includes a built-in **Developer Mode** designed to help developers debug every request inside the application.

---

## 🟡 SmartCacheMode

```dart
SmartCacheMode.dev
SmartCacheMode.production
```

---

# 🧪 Dev Mode Features

When enabled, Smart Cache becomes fully observable.

---

## 1. Console Logging

Every request is logged:

```text
[SmartCache] GET /users
→ CACHE MISS
→ FETCH API
→ RESPONSE: 200 OK
→ STORED (TTL: 1h)
```

---

## 2. Request Tracking

Tracks:

* Request key
* Response data
* Cache status
* Execution time
* Errors

---

## 3. Real-Time Dev Overlay (UI)

### 🔥 Floating Debug Button

When in dev mode, a floating button appears inside the app:

```text
🧠 Smart Cache
```

---

### 📊 Dev Panel Screen

On click, a full debug panel opens showing live requests:

```text
GET /users
→ CACHE MISS
→ 120ms

GET /profile
→ CACHE HIT
→ 2ms

POST /order
→ FAILED (timeout)
```

---

## 4. Request Details Viewer

Each request can be expanded:

```text
KEY: /users

REQUEST:
{
  "page": 1
}

RESPONSE:
[
  { "id": 1, "name": "Ali" }
]

CACHE STATUS: MISS
TIME: 120ms
```

---

## 5. Dev Mode Safety

Dev tools are:

* Automatically disabled in production
* Tree-shaken when not used
* Zero performance impact in release builds

---

# 🏗 Architecture

```text
UI
│
▼
Repository Layer
│
▼
SmartCacheManager
│
├── Memory Storage
├── Future Storages (Hive / Isar / SQLite)
│
├── Dev Event Stream
│
└── Dev Overlay System (Debug UI)
```

---

# 📦 Package Structure

```text
smart_cache/

lib/

├── smart_cache.dart

└── src/

    cache_manager.dart
    cache_entry.dart
    cache_storage.dart

    storage/
        memory_cache_storage.dart

    dev/
        cache_event.dart
        cache_event_type.dart
        cache_event_stream.dart
        smart_cache_overlay.dart
        cache_debug_screen.dart

    utils/
```

---

# 🧠 Cache Entry Model

Each cached item includes:

```dart
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  bool get isExpired;
}
```

---

# ⚙️ Core API

## Get Data

```dart
final users = await cache.get(
  key: 'users',
  fetcher: () => api.getUsers(),
  ttl: Duration(hours: 1),
);
```

---

## Set Data

```dart
await cache.set(
  key: 'users',
  data: users,
);
```

---

## Delete

```dart
await cache.delete('users');
```

---

## Clear All

```dart
await cache.clear();
```

---

# 📡 Dev Event System

Smart Cache emits real-time events:

```dart
class CacheEvent {
  final String key;
  final CacheEventType type;
  final dynamic request;
  final dynamic response;
  final int durationMs;
  final DateTime timestamp;
}
```

---

## Event Types

* hit
* miss
* fetch
* store
* expired
* error

---

# 🎮 Dev Overlay Integration

Enable inside Flutter app:

```dart
MaterialApp(
  builder: (context, child) {
    return Stack(
      children: [
        child!,
        SmartCacheOverlay(cache),
      ],
    );
  },
);
```

---

# 🔐 Production Safety

Dev features are only active when:

```dart
SmartCacheMode.dev
```

In production:

* Overlay is disabled
* Logging is removed
* No performance overhead

---

# 📊 Future Features Roadmap

## Phase 1 (MVP)

* Memory Cache
* TTL System
* Basic Fetch Flow

---

## Phase 2

* Cache Policies
* Expiration Control
* Stats System

---

## Phase 3

* Request Deduplication
* Stale While Revalidate
* Background Refresh

---

## Phase 4

* Hive / Isar / SQLite Support
* Persistent Storage Layer

---

## Phase 5

* Dio Integration
* Tags System
* Auto Invalidation

---

## Phase 6

* Reactive Streams
* UI Auto Updates

---

## Phase 7 (Advanced)

* Offline Queue
* Background Sync
* Encryption
* Compression

---

## Phase 8 (DevTools Expansion)

* Full Dev Dashboard
* Request Timeline Viewer
* Performance Analytics
* Export Logs (JSON/CSV)

---

# 📈 Success Vision

Smart Cache aims to become:

> The React Query of Flutter ecosystem.

---

# 📜 License

MIT License

---

Built with ❤️ for Flutter developers who care about performance, simplicity, and debugging clarity.
