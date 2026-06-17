import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import 'policies_screen.dart';
import 'reactive_screen.dart';
import 'auth_screen.dart';
import 'security_screen.dart';
import 'sync_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final CacheService cacheService;

  const HomeScreen({super.key, required this.cacheService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _OverviewScreen(cacheService: widget.cacheService),
      PoliciesScreen(cacheService: widget.cacheService),
      ReactiveScreen(cacheService: widget.cacheService),
      AuthScreen(cacheService: widget.cacheService),
      SecurityScreen(cacheService: widget.cacheService),
      SyncScreen(cacheService: widget.cacheService),
      StatsScreen(cacheService: widget.cacheService),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.policy), label: 'Policies'),
          NavigationDestination(icon: Icon(Icons.cached), label: 'Reactive'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Auth'),
          NavigationDestination(icon: Icon(Icons.lock), label: 'Security'),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Stats'),
        ],
      ),
    );
  }
}

class _OverviewScreen extends StatelessWidget {
  final CacheService cacheService;

  const _OverviewScreen({required this.cacheService});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Cache Demo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'A full demonstration of every cache_nexus feature using Dio.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _FeatureTile(
                    icon: Icons.policy,
                    title: 'Cache Policies',
                    subtitle:
                        '5 strategies: cacheFirst, networkFirst, cacheOnly, networkOnly, SWR',
                    color: Colors.blue,
                  ),
                  _FeatureTile(
                    icon: Icons.cached,
                    title: 'Reactive Streams',
                    subtitle: 'watch() API + CacheNexusBuilder widget',
                    color: Colors.green,
                  ),
                  _FeatureTile(
                    icon: Icons.person,
                    title: 'Auth-Aware Isolation',
                    subtitle: 'User/role-based cache key isolation',
                    color: Colors.orange,
                  ),
                  _FeatureTile(
                    icon: Icons.lock,
                    title: 'Security Layer',
                    subtitle: 'Encryption + compression decorators',
                    color: Colors.red,
                  ),
                  _FeatureTile(
                    icon: Icons.sync,
                    title: 'Offline Sync',
                    subtitle: 'Persistent queue with automatic retry',
                    color: Colors.purple,
                  ),
                  _FeatureTile(
                    icon: Icons.analytics,
                    title: 'Observability',
                    subtitle: 'Live events, stats, hit rate tracking',
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
