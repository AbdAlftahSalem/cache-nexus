class CacheStats {
  final int hits;
  final int misses;
  final int fetches;
  final int errors;

  CacheStats({
    this.hits = 0,
    this.misses = 0,
    this.fetches = 0,
    this.errors = 0,
  });

  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0.0;
    return hits / total;
  }

  CacheStats copyWith({
    int? hits,
    int? misses,
    int? fetches,
    int? errors,
  }) {
    return CacheStats(
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      fetches: fetches ?? this.fetches,
      errors: errors ?? this.errors,
    );
  }

  @override
  String toString() {
    return 'CacheStats(hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}
