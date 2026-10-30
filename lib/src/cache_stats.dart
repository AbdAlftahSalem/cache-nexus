/// Counters collected in dev mode.
class CacheStats {
  /// Values served from the cache.
  final int hits;

  /// Lookups that found nothing usable.
  final int misses;

  /// Successful fetches.
  final int fetches;

  /// Errors (fetcher, storage, decoding).
  final int errors;

  /// Recorded HTTP requests.
  final int totalRequests;

  /// Requests that got a response with status < 400.
  final int successfulRequests;

  /// Requests that failed or got status >= 400.
  final int failedRequests;

  /// Sum of the successful requests' durations.
  final int totalResponseTimeMs;

  /// Creates a stats snapshot.
  CacheStats({
    this.hits = 0,
    this.misses = 0,
    this.fetches = 0,
    this.errors = 0,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.totalResponseTimeMs = 0,
  });

  /// `hits / (hits + misses)`, 0 when nothing was looked up.
  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0.0;
    return hits / total;
  }

  /// `successfulRequests / totalRequests`, 0 without requests.
  double get successRate {
    if (totalRequests == 0) return 0.0;
    return successfulRequests / totalRequests;
  }

  /// Average duration of successful requests in milliseconds.
  double get averageResponseTimeMs {
    if (successfulRequests == 0) return 0.0;
    return totalResponseTimeMs / successfulRequests;
  }

  /// Returns a copy with the given counters replaced.
  CacheStats copyWith({
    int? hits,
    int? misses,
    int? fetches,
    int? errors,
    int? totalRequests,
    int? successfulRequests,
    int? failedRequests,
    int? totalResponseTimeMs,
  }) {
    return CacheStats(
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      fetches: fetches ?? this.fetches,
      errors: errors ?? this.errors,
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      failedRequests: failedRequests ?? this.failedRequests,
      totalResponseTimeMs: totalResponseTimeMs ?? this.totalResponseTimeMs,
    );
  }

  @override
  String toString() {
    return 'CacheStats(hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'requests: $totalRequests, success: $successfulRequests, failed: $failedRequests, '
        'avgResponse: ${averageResponseTimeMs.toStringAsFixed(1)}ms)';
  }
}
