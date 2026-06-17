import 'package:flutter/material.dart';
import '../cache_stats.dart';

class CacheStatsWidget extends StatelessWidget {
  final CacheStats stats;

  const CacheStatsWidget({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Cache stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Hits', stats.hits.toString(), Colors.green),
              _buildStat('Misses', stats.misses.toString(), Colors.orange),
              _buildStat('Fetches', stats.fetches.toString(), Colors.blue),
              _buildStat('Errors', stats.errors.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: stats.hitRate,
            backgroundColor: Colors.grey[200],
            color: Colors.green,
            minHeight: 10,
          ),
          const SizedBox(height: 4),
          Text(
            'Hit Rate: ${(stats.hitRate * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // Network stats row
          if (stats.totalRequests > 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Requests',
                  stats.totalRequests.toString(),
                  Colors.indigo,
                ),
                _buildStat(
                  'Success',
                  stats.successfulRequests.toString(),
                  Colors.green,
                ),
                _buildStat(
                  'Failed',
                  stats.failedRequests.toString(),
                  Colors.red,
                ),
                _buildStat(
                  'Avg Time',
                  '${stats.averageResponseTimeMs.toStringAsFixed(0)}ms',
                  Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stats.successRate,
              backgroundColor: Colors.grey[200],
              color: Colors.indigo,
              minHeight: 10,
            ),
            const SizedBox(height: 4),
            Text(
              'Success Rate: ${(stats.successRate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
