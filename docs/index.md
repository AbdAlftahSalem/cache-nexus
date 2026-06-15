# Smart Cache Documentation

Welcome to the Smart Cache documentation. This guide will help you understand and use Smart Cache effectively in your Flutter projects.

---

## Quick Links

- **[Quick Start](getting-started/quick-start.md)** - Get up and running in 5 minutes
- **[API Reference](api/smart-cache-manager.md)** - Complete class documentation
- **[Examples](examples/blog-app/)** - Real-world code examples
- **[FAQ](faq/common-issues.md)** - Common questions and solutions

---

## Documentation Sections

### Getting Started

Perfect for new users who want to try Smart Cache for the first time.

| Document | Description |
|----------|-------------|
| [Installation](getting-started/installation.md) | All installation methods (pub.dev, git, local) |
| [Quick Start](getting-started/quick-start.md) | 5-minute runnable example |
| [Hello World](getting-started/hello-world.md) | Minimal first cache call |

### Guides

In-depth explanations of all Smart Cache features.

| Document | Description |
|----------|-------------|
| [Core Concepts](guides/core-concepts.md) | SmartCacheManager, CacheEntry, CacheStorage |
| [Cache Policies](guides/cache-policies.md) | 5 caching strategies and when to use each |
| [Two-Tier Storage](guides/two-tier-storage.md) | Memory + Hive architecture |
| [Security & Auth](guides/security-auth.md) | Encryption and user isolation |
| [Reactive Streams](guides/reactive-streams.md) | watch() API and SmartCacheBuilder widget |
| [Offline Sync](guides/offline-sync.md) | SyncEngine for offline-first apps |
| [Dev Tools](guides/dev-tools.md) | Debug overlay and event monitoring |

### Examples

Complete, copy-pasteable code examples for common scenarios.

| Example | Description |
|---------|-------------|
| [Blog App](examples/blog-app/) | Posts list, detail, caching policies, reactive UI |
| [Auth Flow](examples/auth-flow/) | Login, user context, cache isolation, logout |
| [Offline Todo](examples/offline-todo/) | Offline-first CRUD with sync queue |
| [Snippets](examples/snippets/) | Focused code examples for specific features |

### Best Practices

Tips and patterns for using Smart Cache effectively.

| Document | Description |
|----------|-------------|
| [Architecture](best-practices/architecture.md) | Singleton pattern, DI, service layer |
| [Error Handling](best-practices/error-handling.md) | Retry strategies, error types, fallbacks |
| [Testing](best-practices/testing.md) | Unit, widget, and integration testing |
| [Performance](best-practices/performance.md) | TTL tuning, key naming, memory management |
| [Migration](best-practices/migration.md) | Moving from Hive, shared_preferences, Riverpod |

### API Reference

Complete documentation for all classes, methods, and properties.

| Document | Description |
|----------|-------------|
| [SmartCacheManager](api/smart-cache-manager.md) | Main cache manager class |
| [CacheStorage](api/cache-storage.md) | Storage interface and implementations |
| [CachePolicy](api/cache-policy.md) | Cache strategy enum |
| [CacheContext](api/cache-context.md) | User isolation |
| [SyncEngine](api/sync-engine.md) | Offline sync queue |
| [SmartCacheBuilder](api/smart-cache-builder.md) | Reactive Flutter widget |
| [Dev Overlay](api/dev-overlay.md) | Debug tools |

### FAQ

Common questions and troubleshooting.

| Document | Description |
|----------|-------------|
| [Common Issues](faq/common-issues.md) | Frequently encountered problems |
| [Troubleshooting](faq/troubleshooting.md) | Step-by-step debugging guide |
| [Glossary](faq/glossary.md) | Smart Cache terminology |

---

## Learning Path

### Beginner (First 30 minutes)

1. [Installation](getting-started/installation.md)
2. [Quick Start](getting-started/quick-start.md)
3. [Core Concepts](guides/core-concepts.md)

### Intermediate (Next 2 hours)

4. [Cache Policies](guides/cache-policies.md)
5. [Two-Tier Storage](guides/two-tier-storage.md)
6. [Blog App Example](examples/blog-app/)
7. [Best Practices](best-practices/architecture.md)

### Advanced (Deep Dive)

8. [Security & Auth](guides/security-auth.md)
9. [Reactive Streams](guides/reactive-streams.md)
10. [Offline Sync](guides/offline-sync.md)
11. [API Reference](api/smart-cache-manager.md)

---

## Need Help?

- Check the [FAQ](faq/common-issues.md) for common solutions
- Browse [examples](examples/) for real-world usage
- Open an issue on [GitHub](https://github.com/AbdAlftahSalem/smart-cache/issues)

---

<p align="center">
  Built with ❤️ for Flutter developers
</p>
