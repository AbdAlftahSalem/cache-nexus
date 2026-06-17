import 'dart:async';

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
  StreamSubscription<CacheEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    // Load recent events that happened before panel opened
    _events.addAll(widget.manager.recentEvents);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = widget.manager.events.listen((event) {
        print('🔵 [CachePanel] Received event: ${event.type} key=${event.key} isNetwork=${event.isNetworkEvent}');
        if (mounted) {
          setState(() {
            _events.insert(0, event);
            if (_events.length > 100) _events.removeLast();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkEvents = _events.where((e) => e.isNetworkEvent).toList();
    final cacheEvents = _events.where((e) => !e.isNetworkEvent).toList();
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
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'NETWORK'),
                      Tab(text: 'CACHE'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildEventList(networkEvents, true),
                        _buildEventList(cacheEvents, false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(List<CacheEvent> events, bool isNetwork) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          leading: _getIconForType(event.type),
          title: Text(
            isNetwork ? '${event.method ?? ''} ${event.url ?? event.key}' : event.key,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${event.type.name.toUpperCase()} • ${event.timestamp.toIso8601String().split('T').last.substring(0, 8)}${event.responseStatusCode != null ? ' • ${event.responseStatusCode}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: event.duration != null
              ? Text('${event.duration!.inMilliseconds}ms')
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => CacheDetailScreen(
                  event: event,
                  allEvents: _events.where((e) => e.key == event.key).toList(),
                ),
              ),
            );
          },
        );
      },
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
      case CacheEventType.networkRequest:
        return const Icon(Icons.arrow_upward, color: Colors.blue);
      case CacheEventType.networkResponse:
        return const Icon(Icons.arrow_downward, color: Colors.green);
      case CacheEventType.networkError:
        return const Icon(Icons.error_outline, color: Colors.red);
    }
  }
}
