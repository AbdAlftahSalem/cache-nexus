import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import 'services/cache_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cacheService = await CacheService.create();
  runApp(CacheNexusApp(cacheService: cacheService));
}

class CacheNexusApp extends StatelessWidget {
  final CacheService cacheService;

  const CacheNexusApp({super.key, required this.cacheService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cache Nexus Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      // The overlay works here even though no Navigator is above it.
      builder: (context, child) =>
          CacheNexusOverlay(manager: cacheService.cache, child: child!),
      home: HomeScreen(cacheService: cacheService),
    );
  }
}
