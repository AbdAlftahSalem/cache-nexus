class SyncMetadata {
  final String version;
  final DateTime updatedAt;
  final String deviceId;

  SyncMetadata({
    required this.version,
    required this.updatedAt,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'deviceId': deviceId,
  };

  factory SyncMetadata.fromJson(Map<String, dynamic> json) => SyncMetadata(
    version: json['version'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deviceId: json['deviceId'] as String,
  );
}
