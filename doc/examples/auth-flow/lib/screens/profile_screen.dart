import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.of(context);
    final cache = authService.cache;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('User ID: ${authService.currentUserId}'),
                    Text('Role: ${authService.currentUserRole}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cached Profile
            const Text(
              'Cached Profile:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SmartCacheBuilder<Map<String, dynamic>>(
              cache: cache,
              cacheKey: 'profile',
              builder: (context, profile) {
                if (profile == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No profile cached'),
                    ),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: ${profile['email']}'),
                        Text('Name: ${profile['name']}'),
                        Text('Role: ${profile['role']}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Cache Actions
            const Text(
              'Cache Actions:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await cache.set<Map<String, dynamic>>(
                      key: 'profile',
                      data: {
                        'id': authService.currentUserId,
                        'email': 'updated@example.com',
                        'name': 'Updated Name',
                        'role': authService.currentUserRole,
                      },
                      ttl: const Duration(hours: 1),
                    );
                  },
                  child: const Text('Update Profile'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await cache.delete('profile');
                  },
                  child: const Text('Delete Profile'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await cache.invalidateByContext(
                      CacheContext(userId: authService.currentUserId!),
                    );
                  },
                  child: const Text('Invalidate User'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
