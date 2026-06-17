import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import '../models/post.dart';
import '../services/cache_service.dart';

class SyncScreen extends StatefulWidget {
  final CacheService cacheService;

  const SyncScreen({super.key, required this.cacheService});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final List<SyncTask> _tasks = [];
  final List<String> _logs = [];
  bool _isOnline = true;
  StreamSubscription<List<SyncTask>>? _queueSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tasks.addAll(widget.cacheService.syncEngine.pendingTasks);
    _queueSubscription = widget.cacheService.syncEngine.onQueueChanged.listen((
      tasks,
    ) {
      if (mounted) {
        setState(() {
          _tasks
            ..clear()
            ..addAll(tasks);
        });
      }
    });
    _connectivitySubscription = NetworkStatus.onConnectivityChanged.listen((
      online,
    ) {
      if (mounted) {
        setState(() => _isOnline = online);
        _addLog(online ? 'Network: ONLINE' : 'Network: OFFLINE');
      }
    });
    _addLog('Sync screen initialized');
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} $message');
      if (_logs.length > 50) {
        _logs.removeRange(0, _logs.length - 50);
      }
    });
  }

  Future<void> _enqueueTask() async {
    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      userId: 1,
      title: 'Offline Post ${_tasks.length + 1}',
      body: 'Created while offline, will sync when online',
    );
    await widget.cacheService.enqueueCreatePost(post);
    _addLog('Enqueued: POST ${post.title}');
  }

  Future<void> _processQueue() async {
    _addLog('Processing queue...');
    try {
      await widget.cacheService.syncEngine.processQueue();
      _addLog('Queue processed');
    } catch (e) {
      _addLog('Error: $e');
    }
  }

  Future<void> _clearQueue() async {
    await widget.cacheService.syncEngine.clearQueue();
    _addLog('Queue cleared');
  }

  Future<void> _deleteTask(SyncTask task) async {
    await widget.cacheService.syncEngine.deleteTask(task.id);
    _addLog('Deleted task: ${task.id}');
  }

  void _toggleNetwork() {
    final newStatus = !_isOnline;
    NetworkStatus.setMockStatus(newStatus);
    _addLog(newStatus ? 'Set mock: ONLINE' : 'Set mock: OFFLINE');
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => t.retryCount < 3).toList();
    final failed = _tasks.where((t) => t.retryCount >= 3).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Sync',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Offline-first sync queue with automatic retry',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildStatusRow(context),
            const SizedBox(height: 12),
            _buildActions(),
            const SizedBox(height: 12),
            _buildNetworkToggle(context),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (pending.isNotEmpty) ...[
                    _sectionHeader(
                      'Pending Tasks',
                      pending.length,
                      Colors.orange,
                    ),
                    ...pending.map((t) => _buildTaskCard(t, failed: false)),
                    const SizedBox(height: 12),
                  ],
                  if (failed.isNotEmpty) ...[
                    _sectionHeader('Failed Tasks', failed.length, Colors.red),
                    ...failed.map((t) => _buildTaskCard(t, failed: true)),
                    const SizedBox(height: 12),
                  ],
                  if (_tasks.isEmpty) _buildEmptyState(),
                  _buildLogSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    final pendingCount = _tasks.where((t) => t.retryCount < 3).length;
    final failedCount = _tasks.where((t) => t.retryCount >= 3).length;

    return Row(
      children: [
        Chip(
          avatar: Icon(
            _isOnline ? Icons.cloud : Icons.cloud_off,
            size: 18,
            color: _isOnline ? Colors.green : Colors.red,
          ),
          label: Text(_isOnline ? 'Online' : 'Offline'),
          backgroundColor: (_isOnline ? Colors.green : Colors.red).withValues(
            alpha: 0.1,
          ),
          side: BorderSide(
            color: (_isOnline ? Colors.green : Colors.red).withValues(
              alpha: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          avatar: const Icon(Icons.queue, size: 18),
          label: Text('$pendingCount pending'),
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        if (failedCount > 0) ...[
          const SizedBox(width: 8),
          Chip(
            avatar: Icon(Icons.error, size: 18, color: Colors.red.shade700),
            label: Text('$failedCount failed'),
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _enqueueTask,
          icon: const Icon(Icons.add),
          label: const Text('Enqueue Task'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _tasks.isEmpty ? null : _processQueue,
          icon: const Icon(Icons.sync),
          label: const Text('Process Queue'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _tasks.isEmpty ? null : _clearQueue,
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Clear All'),
        ),
      ],
    );
  }

  Widget _buildNetworkToggle(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: _isOnline ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulate Offline',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Toggle mock network status for testing',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: !_isOnline,
              onChanged: (_) => _toggleNetwork(),
              activeThumbColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(SyncTask task, {required bool failed}) {
    final methodColor = switch (task.method) {
      'POST' => Colors.green,
      'DELETE' => Colors.red,
      'PUT' => Colors.blue,
      'PATCH' => Colors.orange,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: failed
          ? RoundedRectangleBorder(
              side: BorderSide(color: Colors.red.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: methodColor.withValues(alpha: 0.15),
          child: Text(
            task.method.substring(0, min(task.method.length, 3)),
            style: TextStyle(
              color: methodColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          task.endpoint,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Created ${task.createdAt.toString().substring(11, 19)}'
          '${task.retryCount > 0 ? ' · Retry ${task.retryCount}/3' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: failed ? Colors.red : Colors.grey.shade600,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 20,
            color: failed ? Colors.red : Colors.grey,
          ),
          onPressed: () => _deleteTask(task),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pending tasks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Enqueue Task" to add items to the sync queue',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Activity Log', _logs.length, Colors.teal),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No activity yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[_logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

int min(int a, int b) => a < b ? a : b;
