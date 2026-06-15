class CacheStats {
  final int hits;
  final int misses;
  final int fetches;
  final int errors;

  // Network statistics
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int totalResponseTimeMs;

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

  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0.0;
    return hits / total;
  }

  double get successRate {
    if (totalRequests == 0) return 0.0;
    return successfulRequests / totalRequests;
  }

  double get averageResponseTimeMs {
    if (successfulRequests == 0) return 0.0;
    return totalResponseTimeMs / successfulRequests;
  }

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
