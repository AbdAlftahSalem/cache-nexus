class CacheContext {
  final String userId;
  final String? token;
  final String? role;

  const CacheContext({
    required this.userId,
    this.token,
    this.role,
  });

  @override
  String toString() => 'CacheContext(userId: $userId, role: $role)';

  String get cacheKeyPrefix {
    if (role != null) {
      return '${userId}_${role}_';
    }
    return '${userId}_';
  }
}
