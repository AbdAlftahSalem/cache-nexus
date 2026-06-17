import 'package:flutter/material.dart';
import '../cache_manager.dart';
import '../cache_nexus_mode.dart';
import 'cache_panel_screen.dart';

class CacheNexusOverlay extends StatelessWidget {
  final CacheNexusManager manager;
  final Widget child;

  const CacheNexusOverlay({
    super.key,
    required this.manager,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (manager.mode != CacheNexusMode.dev) {
      return child;
    }

    return Scaffold(
      body: Stack(
        children: [
          child,
          Positioned(
            right: 24,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.psychology, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
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
