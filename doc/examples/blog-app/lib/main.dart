import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import 'services/cache_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cacheService = await CacheService.create();
  runApp(SmartCacheApp(cacheService: cacheService));
}

class SmartCacheApp extends StatelessWidget {
  final CacheService cacheService;

  const SmartCacheApp({super.key, required this.cacheService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Cache Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: SmartCacheOverlay(
        manager: cacheService.cache,
        child: HomeScreen(cacheService: cacheService),
      ),
    );
  }
}
