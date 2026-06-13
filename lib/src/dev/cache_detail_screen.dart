import 'dart:convert';
import 'package:flutter/material.dart';
import '../cache_event.dart';
import 'cache_timeline_widget.dart';

class CacheDetailScreen extends StatelessWidget {
  final CacheEvent event;
  final List<CacheEvent> allEvents;

  const CacheDetailScreen({
    super.key,
    required this.event,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('KEY', event.key),
            _buildSection('TYPE', event.type.name.toUpperCase()),
            _buildSection('TIMESTAMP', event.timestamp.toString()),
            if (event.duration != null)
              _buildSection('DURATION', '${event.duration!.inMilliseconds}ms'),
            if (event.error != null)
              _buildSection('ERROR', event.error.toString(), color: Colors.red),
            const SizedBox(height: 20),
            const Text('TIMELINE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            CacheTimelineWidget(events: allEvents),
            const SizedBox(height: 20),
            const Text('DATA SNAPSHOT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _formatData(event.data),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text(value, style: TextStyle(fontSize: 16, color: color)),
        ],
      ),
    );
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (_) {
      return data.toString();
    }
  }
}
