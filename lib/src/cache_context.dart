/// Identifies the signed-in user (and optionally their role) so cached data is
/// isolated per user.
///
/// When a context is set on `CacheNexusManager`, every key is prefixed with
/// [cacheKeyPrefix], so two users on the same device never read each other's
/// data, and `invalidateByContext` can wipe one user's data on logout.
class CacheContext {
  /// The user's unique id.
  final String userId;

  /// The user's auth token. Never part of the cache key.
  final String? token;

  /// An optional role; data is isolated per user *and* role.
  final String? role;

  /// Creates a context.
  const CacheContext({required this.userId, this.token, this.role});

  @override
  String toString() => 'CacheContext(userId: $userId, role: $role)';

  @override
  bool operator ==(Object other) =>
      other is CacheContext &&
      other.userId == userId &&
      other.role == role &&
      other.token == token;

  @override
  int get hashCode => Object.hash(userId, role, token);

  /// The prefix that scopes keys to this user, regardless of role.
  ///
  /// Length-prefixed, so ids containing separators cannot collide
  /// (`ali` + role `admin` and user `ali_admin` get different prefixes).
  String get userKeyPrefix => 'u${userId.length}:$userId|';

  /// The prefix added to every key while this context is active.
  String get cacheKeyPrefix {
    final r = role;
    return r == null ? '${userKeyPrefix}r|' : '${userKeyPrefix}r${r.length}:$r|';
  }

  /// The ambiguous prefix used by version 1.0.0, kept so data written by 1.0
  /// can be found and migrated on first read.
  String get legacyCacheKeyPrefix {
    if (role != null) {
      return '${userId}_${role}_';
    }
    return '${userId}_';
  }
}
