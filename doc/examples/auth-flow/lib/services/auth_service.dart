// ignore_for_file: must_be_immutable
import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';

class AuthService extends InheritedWidget {
  final SmartCacheManager cache;
  String? _currentUserId;
  String? _currentUserRole;

  AuthService({
    super.key,
    required this.cache,
    required super.child,
  });

  static AuthService of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthService>()!;
  }

  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;

  Future<void> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Determine user info based on email
    if (email == 'admin@example.com') {
      _currentUserId = 'user_123';
      _currentUserRole = 'admin';
    } else {
      _currentUserId = 'user_456';
      _currentUserRole = 'guest';
    }

    // Set cache context
    cache.setContext(CacheContext(
      userId: _currentUserId!,
      role: _currentUserRole!,
    ));

    // Cache user profile
    await cache.set<Map<String, dynamic>>(
      key: 'profile',
      data: {
        'id': _currentUserId,
        'email': email,
        'name': email.split('@').first,
        'role': _currentUserRole,
      },
      ttl: const Duration(hours: 1),
    );
  }

  Future<void> logout() async {
    // Invalidate user-specific cache
    if (_currentUserId != null) {
      await cache.invalidateByContext(
        CacheContext(userId: _currentUserId!),
      );
    }

    // Clear context
    cache.clearContext();
    _currentUserId = null;
    _currentUserRole = null;
  }

  @override
  bool updateShouldNotify(AuthService oldWidget) {
    return _currentUserId != oldWidget._currentUserId ||
           _currentUserRole != oldWidget._currentUserRole;
  }
}
