/// Offline-first, debuggable data orchestration layer for Flutter.
///
/// Features TTL caching, 5 cache policies, encryption, auth-aware isolation,
/// reactive streams, offline sync, and built-in dev tools.
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
export 'src/smart_cache_mode.dart';
export 'src/dev/smart_cache_overlay.dart';
export 'src/dev/dio_interceptor.dart';
export 'src/smart_cache_builder.dart';
export 'src/observability_manager.dart';
export 'src/policy_resolver.dart';
export 'src/reactive_engine.dart';
export 'src/type_adapter.dart';
