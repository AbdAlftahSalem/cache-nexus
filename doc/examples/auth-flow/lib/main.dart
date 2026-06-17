import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache
  final cache = SmartCacheManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: SecureCacheStorage(
      MemoryCacheStorage(),
      encryptor: SimpleEncryptor('auth_secret_key'),
      compressor: SimpleCompressor(),
    ),
    mode: SmartCacheMode.dev,
  );

  runApp(AuthFlowApp(cache: cache));
}

class AuthFlowApp extends StatelessWidget {
  final SmartCacheManager cache;

  const AuthFlowApp({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Flow Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: SmartCacheOverlay(
        manager: cache,
        child: AuthService(cache: cache, child: LoginScreen()),
      ),
    );
  }
}
