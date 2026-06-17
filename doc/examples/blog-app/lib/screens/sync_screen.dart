import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../models/post.dart';
import '../services/cache_service.dart';

class SyncScreen extends StatefulWidget {
  final CacheService cacheService;

  const SyncScreen({super.key, required this.cacheService});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final List<String> _logs = [];
  bool _isOnline = true;

  void _addLog(String message) {
    setState(() => _logs.add('${DateTime.now().toString().substring(11, 19)} $message'));
  }

  Future<void> _enqueueTask() async {
    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      userId: 1,
      title: 'Offline Post ${_logs.length + 1}',
      body: 'Created while offline, will sync when online',
    );
    await widget.cacheService.enqueueCreatePost(post);
    _addLog('Enqueued create post: ${post.title}');
  }

  Future<void> _processQueue() async {
    _addLog('Processing queue...');
    try {
      await widget.cacheService.syncEngine.processQueue();
      _addLog('Queue processed successfully');
    } catch (e) {
      _addLog('Queue processing error: $e');
    }
  }

  void _toggleOnline() {
    setState(() => _isOnline = !_isOnline);
    NetworkStatus.setMockStatus(_isOnline);
    _addLog(_isOnline ? 'Set to ONLINE' : 'Set to OFFLINE');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline Sync', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Wrap(
              children: [
                ElevatedButton.icon(
                  onPressed: _enqueueTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Enqueue Task'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _processQueue,
                  icon: const Icon(Icons.sync),
                  label: const Text('Process Queue'),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isOnline,
                  onChanged: (_) => _toggleOnline(),
                ),
                Text(_isOnline ? 'Online' : 'Offline'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: _logs.isEmpty
                    ? const Center(child: Text('No sync logs yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
