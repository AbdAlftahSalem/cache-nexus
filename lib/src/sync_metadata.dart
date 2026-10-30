/// Version information you can attach to synced records (for example to
/// detect conflicts). Not used by the engine itself.
class SyncMetadata {
  /// The record version (e.g. an ETag or a counter).
  final String version;

  /// When the record was last updated.
  final DateTime updatedAt;

  /// The device that made the update.
  final String deviceId;

  /// Creates metadata.
  SyncMetadata({
    required this.version,
    required this.updatedAt,
    required this.deviceId,
  });

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'deviceId': deviceId,
  };

  /// Restores from [toJson] output.
  factory SyncMetadata.fromJson(Map<String, dynamic> json) => SyncMetadata(
    version: json['version'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deviceId: json['deviceId'] as String,
  );
}
