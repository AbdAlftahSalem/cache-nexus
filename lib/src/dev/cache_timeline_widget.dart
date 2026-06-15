import 'package:flutter/material.dart';
import '../cache_event.dart';

class CacheTimelineWidget extends StatelessWidget {
  final List<CacheEvent> events;

  const CacheTimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.map((e) => _buildTimelineItem(e)).toList(),
    );
  }

  Widget _buildTimelineItem(CacheEvent event) {
    return Row(
      children: [
        Column(
          children: [
            Container(width: 2, height: 20, color: Colors.grey[300]),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getColor(event.type),
              ),
            ),
            Container(width: 2, height: 20, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.type.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                event.timestamp.toIso8601String().split('T').last.substring(0, 8),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColor(CacheEventType type) {
    switch (type) {
      case CacheEventType.hit: return Colors.green;
      case CacheEventType.miss: return Colors.orange;
      case CacheEventType.fetch: return Colors.blue;
      case CacheEventType.error: return Colors.red;
      case CacheEventType.store: return Colors.blueGrey;
      case CacheEventType.expired: return Colors.grey;
      case CacheEventType.evict: return Colors.black54;
      case CacheEventType.networkRequest: return Colors.blue;
      case CacheEventType.networkResponse: return Colors.green;
      case CacheEventType.networkError: return Colors.red;
    }
  }
}
