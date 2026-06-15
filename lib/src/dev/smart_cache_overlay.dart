import 'package:flutter/material.dart';
import '../cache_manager.dart';
import '../smart_cache_mode.dart';
import 'cache_panel_screen.dart';

class SmartCacheOverlay extends StatelessWidget {
  final SmartCacheManager manager;
  final Widget child;

  const SmartCacheOverlay({
    super.key,
    required this.manager,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (manager.mode != SmartCacheMode.dev) {
      return child;
    }

    return Scaffold(
      body: Stack(
        children: [
          child,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.psychology, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CachePanelScreen(manager: manager),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
