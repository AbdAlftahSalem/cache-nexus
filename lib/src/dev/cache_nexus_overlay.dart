import 'package:flutter/material.dart';

import '../cache_manager.dart';
import '../cache_nexus_mode.dart';
import 'cache_panel_screen.dart';

/// Adds a floating button that opens the cache dev panel.
///
/// Renders [child] unchanged unless the manager runs in
/// [CacheNexusMode.dev]. Works both inside `MaterialApp.builder` (where no
/// `Navigator` exists above it) and inside a page:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) =>
///       CacheNexusOverlay(manager: cache, child: child!),
///   home: const HomeScreen(),
/// );
/// ```
///
/// The panel is pushed on [navigatorKey] (or the nearest `Navigator`) when
/// one is available, otherwise it is shown on top of [child] with its own
/// navigator.
class CacheNexusOverlay extends StatefulWidget {
  /// The manager whose events are shown.
  final CacheNexusManager manager;

  /// The app content.
  final Widget child;

  /// The navigator to push the panel on. Optional.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Creates the overlay.
  const CacheNexusOverlay({
    super.key,
    required this.manager,
    required this.child,
    this.navigatorKey,
  });

  @override
  State<CacheNexusOverlay> createState() => _CacheNexusOverlayState();
}

class _CacheNexusOverlayState extends State<CacheNexusOverlay> {
  bool _inlineOpen = false;

  void _open(BuildContext context) {
    final navigator =
        widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CachePanelScreen(manager: widget.manager),
        ),
      );
      return;
    }
    setState(() => _inlineOpen = true);
  }

  void _close() => setState(() => _inlineOpen = false);

  @override
  Widget build(BuildContext context) {
    if (widget.manager.mode != CacheNexusMode.dev) {
      return widget.child;
    }

    return Stack(
      alignment: Alignment.topLeft,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_inlineOpen)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _close();
              },
              child: HeroControllerScope.none(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => CachePanelScreen(
                      manager: widget.manager,
                      onClose: _close,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Positioned(
            right: 24,
            bottom: 100,
            child: Builder(
              builder: (context) => FloatingActionButton(
                mini: true,
                heroTag: null,
                backgroundColor: Colors.blueAccent,
                onPressed: () => _open(context),
                child: const Icon(Icons.psychology, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
