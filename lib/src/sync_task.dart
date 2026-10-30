/// A write operation queued for later delivery by [SyncEngine](package:cache_nexus/cache_nexus.dart).
///
/// [body] is persisted with the queue, so it must be JSON-like data
/// (`Map`, `List`, `String`, `num`, `bool`, `null`). Objects with a
/// `toJson()` method are converted automatically when enqueued.
class SyncTask {
  /// A unique id. Enqueuing a task with an existing id replaces it.
  final String id;

  /// The cache key this write belongs to (for your own bookkeeping).
  final String key;

  /// The endpoint to call, e.g. `/posts`.
  final String endpoint;

  /// The HTTP method, e.g. `POST`.
  final String method;

  /// The request body.
  final dynamic body;

  /// When the task was created. Tasks are sent oldest first.
  final DateTime createdAt;

  /// How many delivery attempts have failed so far.
  int retryCount;

  /// The earliest time the next attempt may run (set by backoff).
  DateTime? nextAttemptAt;

  /// The last error message, if the last attempt failed.
  String? lastError;

  /// Creates a task.
  SyncTask({
    required this.id,
    required this.key,
    required this.endpoint,
    required this.method,
    this.body,
    required this.createdAt,
    this.retryCount = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  /// Serializes the task for the persistent queue.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      if (nextAttemptAt != null)
        'nextAttemptAt': nextAttemptAt!.toIso8601String(),
      if (lastError != null) 'lastError': lastError,
    };
  }

  /// Restores a task written by [toJson].
  factory SyncTask.fromJson(Map<String, dynamic> json) {
    final next = json['nextAttemptAt'];
    return SyncTask(
      id: json['id'] as String,
      key: json['key'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      body: json['body'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      nextAttemptAt: next is String ? DateTime.parse(next) : null,
      lastError: json['lastError'] as String?,
    );
  }

  @override
  String toString() =>
      'SyncTask($id, $method $endpoint, retryCount: $retryCount'
      '${lastError != null ? ', lastError: $lastError' : ''})';
}
