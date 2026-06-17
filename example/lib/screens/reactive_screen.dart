import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import '../models/post.dart';
import '../services/cache_service.dart';

class ReactiveScreen extends StatefulWidget {
  final CacheService cacheService;

  const ReactiveScreen({super.key, required this.cacheService});

  @override
  State<ReactiveScreen> createState() => _ReactiveScreenState();
}

class _ReactiveScreenState extends State<ReactiveScreen> {
  List<Post>? _posts;
  String _status = 'Watching posts stream...';
  StreamSubscription<List<Post>?>? _subscription;

  @override
  void initState() {
    super.initState();
    _startWatching();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startWatching() {
    _subscription = widget.cacheService.cache
        .watch<List<Post>>('reactive_posts')
        .listen((posts) {
          if (mounted) {
            setState(() {
              _posts = posts;
              _status = posts != null
                  ? 'Got ${posts.length} posts from stream'
                  : 'No data yet';
            });
          }
        });
  }

  Future<void> _refreshPosts() async {
    setState(() => _status = 'Fetching from API...');
    try {
      final posts = await widget.cacheService.getPosts(
        policy: CachePolicy.networkFirst,
        ttl: const Duration(minutes: 1),
      );
      await widget.cacheService.cache.set(
        key: 'reactive_posts',
        data: posts,
        ttl: const Duration(minutes: 1),
      );
      setState(() => _status = 'Updated ${posts.length} posts');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Reactive Streams',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _refreshPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Posts'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _posts == null
                ? const Center(
                    child: Text('No cached data. Tap Refresh to fetch.'),
                  )
                : ListView.builder(
                    itemCount: _posts!.length,
                    itemBuilder: (context, index) {
                      final post = _posts![index];
                      return ListTile(
                        title: Text(post.title),
                        subtitle: Text(
                          post.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: CircleAvatar(child: Text('${post.id}')),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
