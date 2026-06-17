import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../services/cache_service.dart';

class PoliciesScreen extends StatefulWidget {
  final CacheService cacheService;

  const PoliciesScreen({super.key, required this.cacheService});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  String _result = 'Tap a policy button to fetch posts';
  bool _loading = false;

  Future<void> _fetchPosts(CachePolicy policy, String label) async {
    setState(() {
      _loading = true;
      _result = 'Fetching with $label...';
    });
    try {
      final stopwatch = Stopwatch()..start();
      final posts = await widget.cacheService.getPosts(
        policy: policy,
        ttl: const Duration(seconds: 30),
      );
      stopwatch.stop();
      setState(() {
        _loading = false;
        _result =
            '[$label] Fetched ${posts.length} posts in ${stopwatch.elapsedMilliseconds}ms';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _result = '[$label] Error: $e';
      });
    }
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
              'Cache Policies',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '5 strategies with Dio fetching from jsonplaceholder.typicode.com',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _PolicyCard(
                    title: 'cacheFirst',
                    description: 'Check cache first. Fetch on miss/expiry.',
                    color: Colors.blue,
                    onTap: () =>
                        _fetchPosts(CachePolicy.cacheFirst, 'cacheFirst'),
                  ),
                  _PolicyCard(
                    title: 'networkFirst',
                    description: 'Network first. Fall back to cache on error.',
                    color: Colors.green,
                    onTap: () =>
                        _fetchPosts(CachePolicy.networkFirst, 'networkFirst'),
                  ),
                  _PolicyCard(
                    title: 'cacheOnly',
                    description: 'Never hit network. Return cache or throw.',
                    color: Colors.orange,
                    onTap: () =>
                        _fetchPosts(CachePolicy.cacheOnly, 'cacheOnly'),
                  ),
                  _PolicyCard(
                    title: 'networkOnly',
                    description: 'Always fetch. Cache is ignored.',
                    color: Colors.red,
                    onTap: () =>
                        _fetchPosts(CachePolicy.networkOnly, 'networkOnly'),
                  ),
                  _PolicyCard(
                    title: 'staleWhileRevalidate',
                    description:
                        'Return stale instantly, refresh in background.',
                    color: Colors.purple,
                    onTap: () => _fetchPosts(
                      CachePolicy.staleWhileRevalidate,
                      'staleWhileRevalidate',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _result,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _PolicyCard({
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(Icons.play_arrow, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
