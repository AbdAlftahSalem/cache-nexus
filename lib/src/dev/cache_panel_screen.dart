import 'package:flutter/material.dart';
import '../cache_manager.dart';
import '../cache_event.dart';
import 'cache_stats_widget.dart';
import 'cache_detail_screen.dart';

class CachePanelScreen extends StatefulWidget {
  final SmartCacheManager manager;

  const CachePanelScreen({super.key, required this.manager});

  @override
  State<CachePanelScreen> createState() => _CachePanelScreenState();
}

class _CachePanelScreenState extends State<CachePanelScreen> {
  final List<CacheEvent> _events = [];

  @override
  void initState() {
    super.initState();
    widget.manager.events.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 100) _events.removeLast();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Cache Dev Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => widget.manager.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          CacheStatsWidget(stats: widget.manager.stats),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('LIVE REQUESTS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return ListTile(
                  leading: _getIconForType(event.type),
                  title: Text(event.key, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${event.type.name.toUpperCase()} • ${event.timestamp.toIso8601String().split('T').last.substring(0, 8)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: event.duration != null
                      ? Text('${event.duration!.inMilliseconds}ms')
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CacheDetailScreen(
                          event: event,
                          allEvents: _events.where((e) => e.key == event.key).toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIconForType(CacheEventType type) {
    switch (type) {
      case CacheEventType.hit:
        return const Icon(Icons.check_circle, color: Colors.green);
      case CacheEventType.miss:
        return const Icon(Icons.radio_button_unchecked, color: Colors.orange);
      case CacheEventType.fetch:
        return const Icon(Icons.cloud_download, color: Colors.blue);
      case CacheEventType.error:
        return const Icon(Icons.error, color: Colors.red);
      case CacheEventType.store:
        return const Icon(Icons.save, color: Colors.blueGrey);
      case CacheEventType.expired:
        return const Icon(Icons.timer_off, color: Colors.grey);
      case CacheEventType.evict:
        return const Icon(Icons.delete, color: Colors.black54);
    }
  }
}
