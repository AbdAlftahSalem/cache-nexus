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
    final isNetwork = event.isNetworkEvent;

    return Scaffold(
      appBar: AppBar(title: Text(isNetwork ? 'Network Request' : 'Cache Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _buildSection('KEY', event.key),
            // _buildSection('TYPE', event.type.name.toUpperCase()),
            _buildSection('TIMESTAMP', event.timestamp.toString()),
            if (event.duration != null)
              _buildSection('DURATION', '${event.duration!.inMilliseconds}ms'),
            if (event.error != null)
              _buildSection('ERROR', event.error.toString(), color: Colors.red),
            if (isNetwork) ...[
              const SizedBox(height: 20),
              const Text('REQUEST', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              if (event.method != null) _buildSection('METHOD', event.method!),
              if (event.url != null) _buildSection('URL', event.url!),
              if (event.requestHeaders != null && event.requestHeaders!.isNotEmpty)
                _buildSection('REQUEST HEADERS', _formatData(event.requestHeaders)),
              if (event.requestBody != null)
                _buildSection('REQUEST BODY', _formatJson(event.requestBody)),
              const SizedBox(height: 20),
              const Text('RESPONSE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 10),
              if (event.responseStatusCode != null)
                _buildSection('STATUS CODE', event.responseStatusCode.toString(),
                    color: _getStatusColor(event.responseStatusCode!)),
              if (event.responseBody != null)
                _buildSection('RESPONSE BODY', _formatJson(event.responseBody)),
            ],
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
          SelectableText(value, style: TextStyle(fontSize: 14, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      String str;
      if (data is Map || data is List) {
        str = const JsonEncoder.withIndent('  ').convert(data);
      } else {
        str = data.toString();
      }
      const maxLength = 10000;
      if (str.length > maxLength) {
        return '${str.substring(0, maxLength)}\n\n... [TRUNCATED: ${str.length} chars total]';
      }
      return str;
    } catch (_) {
      return data.toString();
    }
  }

  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    try {
      String str;
      if (data is Map || data is List) {
        str = const JsonEncoder.withIndent('  ').convert(data);
      } else if (data is String) {
        // Try to parse string as JSON
        try {
          final decoded = jsonDecode(data);
          str = const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          str = data.toString();
        }
      } else {
        str = data.toString();
      }
      const maxLength = 10000;
      if (str.length > maxLength) {
        return '${str.substring(0, maxLength)}\n\n... [TRUNCATED: ${str.length} chars total]';
      }
      return str;
    } catch (_) {
      return data.toString();
    }
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.blue;
    if (statusCode >= 400 && statusCode < 500) return Colors.orange;
    return Colors.red;
  }
}
