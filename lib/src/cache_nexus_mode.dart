/// Whether the dev tools record anything.
enum CacheNexusMode {
  /// Record events and stats; show the overlay and capture Dio traffic.
  dev,

  /// Record nothing (the default). The dev widgets render only their child.
  production,
}
