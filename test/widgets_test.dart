import 'package:cache_nexus/cache_nexus.dart';
import 'package:cache_nexus/src/dev/cache_detail_screen.dart';
import 'package:cache_nexus/src/dev/cache_stats_widget.dart';
import 'package:cache_nexus/src/dev/cache_timeline_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => NetworkStatus.setMockStatus(true));

  group('CacheNexusBuilder', () {
    testWidgets('shows loading, then data, then updates', (tester) async {
      final cache = CacheNexusManager();
      await tester.pumpWidget(
        app(
          CacheNexusBuilder<String>(
            cache: cache,
            cacheKey: 'greeting',
            loadingBuilder: (_) => const Text('loading'),
            builder: (_, v) => Text('value: $v'),
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('value: null'), findsOneWidget);

      await tester.runAsync(() => cache.set(key: 'greeting', data: 'مرحبا'));
      await tester.pump();
      expect(find.text('value: مرحبا'), findsOneWidget);

      await tester.runAsync(() => cache.delete('greeting'));
      await tester.pump();
      expect(find.text('value: null'), findsOneWidget);
    });

    testWidgets('errorBuilder receives decode errors', (tester) async {
      final cache = CacheNexusManager();
      await cache.set<String>(key: 'n', data: 'not a number');
      final errors = <Object>[];
      await tester.pumpWidget(
        app(
          CacheNexusBuilder<int>(
            cache: cache,
            cacheKey: 'n',
            onError: (e, _) => errors.add(e),
            errorBuilder: (_, e, last) => Text('error: ${e.runtimeType}'),
            builder: (_, v) => Text('value: $v'),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('value: null'), findsOneWidget);

      await tester.runAsync(() => cache.set<String>(key: 'n', data: 'x'));
      await tester.pump();
      expect(find.text('error: CacheDecodeException'), findsOneWidget);
      expect(errors, hasLength(1));

      await tester.runAsync(() => cache.set<int>(key: 'n', data: 7));
      await tester.pump();
      expect(find.text('value: 7'), findsOneWidget);
    });

    testWidgets('without errorBuilder errors are reported, last value kept', (
      tester,
    ) async {
      final cache = CacheNexusManager();
      await cache.set<int>(key: 'n', data: 1);
      await tester.pumpWidget(
        app(
          CacheNexusBuilder<int>(
            cache: cache,
            cacheKey: 'n',
            builder: (_, v) => Text('value: $v'),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('value: 1'), findsOneWidget);
      await tester.runAsync(() => cache.set<String>(key: 'n', data: 'bad'));
      await tester.pump();
      expect(tester.takeException(), isA<CacheDecodeException>());
      expect(find.text('value: 1'), findsOneWidget);
    });

    testWidgets('re-subscribes when the key changes', (tester) async {
      final cache = CacheNexusManager();
      await cache.set(key: 'a', data: 'A');
      await cache.set(key: 'b', data: 'B');
      Widget build(String key) => app(
        CacheNexusBuilder<String>(
          cache: cache,
          cacheKey: key,
          builder: (_, v) => Text('v=$v'),
        ),
      );
      await tester.pumpWidget(build('a'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('v=A'), findsOneWidget);
      await tester.pumpWidget(build('b'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('v=B'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(cache.reactiveEngine.controllerCount, 0);
    });
  });

  group('CacheNexusOverlay', () {
    testWidgets('production mode renders only the child', (tester) async {
      final cache = CacheNexusManager();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              CacheNexusOverlay(manager: cache, child: child!),
          home: const Text('home'),
        ),
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('inside MaterialApp.builder: open, browse, close', (
      tester,
    ) async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      await tester.runAsync(() async {
        await cache.get<String>(key: 'posts', fetcher: () async => 'p');
        await cache.get<String>(key: 'posts', fetcher: () async => 'p');
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              CacheNexusOverlay(manager: cache, child: child!),
          home: const Scaffold(body: Text('home')),
        ),
      );
      // Only the app's own Scaffold: the overlay adds none.
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Cache Nexus Dev Panel'), findsOneWidget);

      await tester.tap(find.text('CACHE'));
      await tester.pumpAndSettle();
      expect(find.text('posts'), findsWidgets);
      await tester.tap(find.text('posts').first);
      await tester.pumpAndSettle();
      expect(find.text('Cache Event'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Cache Nexus Dev Panel'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inside a page: pushes on the app navigator', (tester) async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      await tester.pumpWidget(
        MaterialApp(
          home: CacheNexusOverlay(
            manager: cache,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Cache Nexus Dev Panel'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('uses navigatorKey when given', (tester) async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (_, child) => CacheNexusOverlay(
            manager: cache,
            navigatorKey: key,
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Cache Nexus Dev Panel'), findsOneWidget);
      expect(key.currentState!.canPop(), isTrue);
    });

    testWidgets('the panel shows network events live and can clear', (
      tester,
    ) async {
      final cache = CacheNexusManager(mode: CacheNexusMode.dev);
      await tester.pumpWidget(
        MaterialApp(
          home: CacheNexusOverlay(
            manager: cache,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final id = cache.recordNetworkRequest(
          url: 'https://api.test/posts',
          method: 'GET',
        );
        cache.recordNetworkResponse(
          requestId: id,
          url: 'https://api.test/posts',
          method: 'GET',
          statusCode: 200,
          body: '{"ok":true}',
          duration: const Duration(milliseconds: 12),
        );
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('GET https://api.test/posts'), findsWidgets);
      await tester.tap(find.textContaining('GET https://api.test/posts').first);
      await tester.pumpAndSettle();
      expect(find.text('Network Request'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('stats, timeline and detail widgets render', (tester) async {
    final now = DateTime(2026, 10, 30, 8);
    final events = [
      for (final t in CacheEventType.values)
        CacheEvent(
          key: 'k-${t.name}',
          type: t,
          timestamp: now,
          duration: const Duration(milliseconds: 5),
          url: 'https://api.test/x',
          method: 'POST',
          requestHeaders: const {'a': 'b'},
          requestBody: const {'q': 1},
          responseStatusCode: 201,
          responseHeaders: const {'c': 'd'},
          responseBody: '{"id": 1}',
          error: t == CacheEventType.error ? 'boom' : null,
          requestId: 'r1',
        ),
    ];
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: Column(
            children: [
              CacheStatsWidget(
                stats: CacheStats(
                  hits: 3,
                  misses: 1,
                  totalRequests: 2,
                  successfulRequests: 1,
                  failedRequests: 1,
                  totalResponseTimeMs: 40,
                ),
              ),
              CacheTimelineWidget(events: events),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final e in events) {
      await tester.pumpWidget(
        MaterialApp(
          home: CacheDetailScreen(event: e, allEvents: events),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
