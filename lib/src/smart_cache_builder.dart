import 'dart:async';

import 'package:flutter/widgets.dart';

import 'cache_manager.dart';

/// A Flutter widget that automatically rebuilds when a cache key changes.
///
/// Example:
/// ```dart
/// SmartCacheBuilder<List<User>>(
///   cache: cache,
///   key: "users",
///   builder: (context, users) {
///     return ListView(
///       children: users.map((u) => Text(u.name)).toList(),
///     );
///   },
/// );
/// ```
class SmartCacheBuilder<T> extends StatefulWidget {
  final SmartCacheManager cache;
  final String cacheKey;
  final Widget Function(BuildContext context, T? data) builder;
  final Duration? debounce;

  const SmartCacheBuilder({
    super.key,
    required this.cache,
    required this.cacheKey,
    required this.builder,
    this.debounce,
  });

  @override
  State<SmartCacheBuilder<T>> createState() => _SmartCacheBuilderState<T>();
}

class _SmartCacheBuilderState<T> extends State<SmartCacheBuilder<T>> {
  T? _data;
  StreamSubscription<T?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant SmartCacheBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cache != widget.cache ||
        oldWidget.cacheKey != widget.cacheKey) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.cache
        .watch<T>(widget.cacheKey, debounce: widget.debounce)
        .listen((data) {
          if (mounted) {
            setState(() {
              _data = data;
            });
          }
        });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _data);
  }
}
