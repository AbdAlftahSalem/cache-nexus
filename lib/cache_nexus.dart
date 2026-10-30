/// Offline-first, debuggable caching and data orchestration for Flutter.
///
/// * [CacheNexusManager]: two-tier (memory + Hive) cache with TTLs and five
///   [CachePolicy] strategies.
/// * [CacheAdapter]: typed values that survive app restarts.
/// * [SecureCacheStorage] with [AesGcmEncryptor] and [GZipCompressor].
/// * [CacheContext]: per-user isolation.
/// * [CacheNexusManager.watch] and [CacheNexusBuilder]: reactive UI.
/// * [SyncEngine]: an offline write queue with retries and backoff.
/// * [CacheNexusOverlay] and [CacheNexusDioInterceptor]: dev tools.
library;

export 'src/cache_manager.dart';
export 'src/cache_entry.dart';
export 'src/cache_storage.dart';
export 'src/memory_cache_storage.dart';
export 'src/hive_cache_storage.dart';
export 'src/secure_cache_storage.dart';
export 'src/cache_encryptor.dart';
export 'src/cache_compressor.dart';
export 'src/cache_context.dart';
export 'src/sync_metadata.dart';
export 'src/cache_policy.dart';
export 'src/cache_event.dart';
export 'src/cache_stats.dart';
export 'src/sync_task.dart';
export 'src/sync_engine.dart';
export 'src/network_status.dart';
export 'src/cache_nexus_mode.dart';
export 'src/dev/cache_nexus_overlay.dart';
export 'src/dev/dio_interceptor.dart';
export 'src/cache_nexus_builder.dart';
export 'src/observability_manager.dart';
export 'src/policy_resolver.dart';
export 'src/reactive_engine.dart';
export 'src/type_adapter.dart';
export 'src/cache_adapter.dart';
export 'src/cache_exceptions.dart';
export 'src/type_registry.dart' show CacheTypeRegistry;
