// ignore: inference_failure_on_instance_creation
import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../services/cache_service.dart';

class AuthScreen extends StatefulWidget {
  final CacheService cacheService;

  const AuthScreen({super.key, required this.cacheService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _currentUser;
  String? _currentRole;
  String _cachedData = 'No data loaded';
  final Map<String, String> _userProfiles = {};

  void _switchUser(String userId, String role) {
    widget.cacheService.cache.setContext(
      CacheContext(userId: userId, role: role),
    );
    setState(() {
      _currentUser = userId;
      _currentRole = role;
    });
  }

  void _clearContext() {
    widget.cacheService.cache.clearContext();
    setState(() {
      _currentUser = null;
      _currentRole = null;
    });
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) {
      setState(() => _cachedData = 'No user context set');
      return;
    }
    final profile = await widget.cacheService.cache.get<String>(
      key: 'profile',
      fetcher: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        return 'Profile for $_currentUser ($_currentRole)';
      },
      ttl: const Duration(minutes: 5),
    );
    setState(() {
      _cachedData = profile;
      _userProfiles['${_currentUser}_$_currentRole'] = profile;
    });
  }

  Future<void> _invalidateCurrentUser() async {
    if (_currentUser == null) return;
    await widget.cacheService.cache.invalidateByContext(
      CacheContext(userId: _currentUser!, role: _currentRole),
    );
    setState(() => _cachedData = 'Cache invalidated for $_currentUser');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auth-Aware Isolation',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (_currentUser != null)
              Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text('$_currentUser ($_currentRole)'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _switchUser('admin_001', 'admin'),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Admin'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _switchUser('guest_002', 'guest'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Guest'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearContext,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('Load Profile'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _invalidateCurrentUser,
                  child: const Text('Invalidate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cached Profile:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_cachedData),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_userProfiles.isNotEmpty) ...[
              const Text(
                'All Loaded Profiles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._userProfiles.entries.map(
                (e) => Card(
                  child: ListTile(
                    title: Text(e.key),
                    subtitle: Text(e.value),
                    dense: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
