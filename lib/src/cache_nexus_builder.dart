import 'dart:async';

import 'package:flutter/widgets.dart';

import 'cache_manager.dart';

/// Rebuilds whenever the value cached under [cacheKey] changes.
///
/// ```dart
/// CacheNexusBuilder<List<User>>(
///   cache: cache,
///   cacheKey: 'users',
///   loadingBuilder: (context) => const CircularProgressIndicator(),
///   errorBuilder: (context, error, users) => Text('$error'),
///   builder: (context, users) {
///     return ListView(
///       children: (users ?? []).map((u) => Text(u.name)).toList(),
///     );
///   },
/// );
/// ```
///
/// The widget only *watches* the key; something else (for example
/// `cache.get` in your repository) has to load the data.
class CacheNexusBuilder<T> extends StatefulWidget {
  /// The manager to watch.
  final CacheNexusManager cache;

  /// The cache key to watch.
  final String cacheKey;

  /// Builds the UI from the current value (`null` while nothing is cached).
  final Widget Function(BuildContext context, T? data) builder;

  /// Builds the UI before the first value arrives. When `null`, [builder]
  /// is called with `null`.
  final WidgetBuilder? loadingBuilder;

  /// Builds the UI when the stream reports an error (for example a cached
  /// value that cannot be read as `T`). Receives the last good value.
  /// When `null`, [builder] keeps showing the last good value.
  final Widget Function(BuildContext context, Object error, T? data)?
  errorBuilder;

  /// Called for every stream error. When neither this nor [errorBuilder] is
  /// set, errors are reported through `FlutterError.reportError`.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Waits until the key has been quiet this long before rebuilding.
  final Duration? debounce;

  /// Creates the builder.
  const CacheNexusBuilder({
    super.key,
    required this.cache,
    required this.cacheKey,
    required this.builder,
    this.debounce,
    this.loadingBuilder,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<CacheNexusBuilder<T>> createState() => _CacheNexusBuilderState<T>();
}

class _CacheNexusBuilderState<T> extends State<CacheNexusBuilder<T>> {
  T? _data;
  Object? _error;
  bool _hasValue = false;
  StreamSubscription<T?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant CacheNexusBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cache != widget.cache ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.debounce != widget.debounce) {
      _unsubscribe();
      _data = null;
      _error = null;
      _hasValue = false;
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
        .listen(
          (data) {
            if (!mounted) return;
            setState(() {
              _data = data;
              _error = null;
              _hasValue = true;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            widget.onError?.call(error, stackTrace);
            if (widget.onError == null && widget.errorBuilder == null) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stackTrace,
                  library: 'cache_nexus',
                  context: ErrorDescription(
                    'while watching cache key "${widget.cacheKey}"',
                  ),
                ),
              );
            }
            if (!mounted) return;
            setState(() {
              _error = error;
              _hasValue = true;
            });
          },
        );
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, _data);
    }
    if (!_hasValue && widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    return widget.builder(context, _data);
  }
}
