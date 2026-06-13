class SyncTask {
  final String id;
  final String key;
  final String endpoint;
  final String method;
  final dynamic body;
  final DateTime createdAt;
  int retryCount;

  SyncTask({
    required this.id,
    required this.key,
    required this.endpoint,
    required this.method,
    this.body,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory SyncTask.fromJson(Map<String, dynamic> json) {
    return SyncTask(
      id: json['id'] as String,
      key: json['key'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      body: json['body'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}
