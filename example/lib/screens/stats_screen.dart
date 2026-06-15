import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../services/cache_service.dart';

class StatsScreen extends StatefulWidget {
  final CacheService cacheService;

  const StatsScreen({super.key, required this.cacheService});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final List<CacheEvent> _events = [];
  StreamSubscription<CacheEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.cacheService.cache.events.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) _events.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.cacheService.cache.stats;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cache Stats', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Hits', value: '${stats.hits}', color: Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Misses', value: '${stats.misses}', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Fetches', value: '${stats.fetches}', color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Errors', value: '${stats.errors}', color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hit Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: stats.hitRate,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 4),
                    Text('${(stats.hitRate * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Live Events', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _events.isEmpty
                  ? const Center(child: Text('No events yet. Perform cache operations to see events.'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: _eventIcon(event.type),
                            title: Text(event.key, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              '${event.type.name} - ${event.timestamp.toString().substring(11, 19)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: event.duration != null
                                ? Text('${event.duration!.inMilliseconds}ms',
                                    style: const TextStyle(fontSize: 12))
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventIcon(CacheEventType type) {
    final (icon, color) = switch (type) {
      CacheEventType.hit => (Icons.check_circle, Colors.green),
      CacheEventType.miss => (Icons.cancel, Colors.orange),
      CacheEventType.fetch => (Icons.download, Colors.blue),
      CacheEventType.store => (Icons.save, Colors.teal),
      CacheEventType.error => (Icons.error, Colors.red),
      CacheEventType.expired => (Icons.timer, Colors.grey),
      CacheEventType.evict => (Icons.delete, Colors.black45),
    };
    return Icon(icon, color: color, size: 20);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
