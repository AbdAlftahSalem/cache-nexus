import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    persistentStorage: SecureCacheStorage(
      MemoryCacheStorage(),
      encryptor: SimpleEncryptor('auth_secret_key'),
      compressor: SimpleCompressor(),
    ),
    mode: CacheNexusMode.dev,
  );

  runApp(AuthFlowApp(cache: cache));
}

class AuthFlowApp extends StatelessWidget {
  final CacheNexusManager cache;

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
      home: CacheNexusOverlay(
        manager: cache,
        child: AuthService(cache: cache, child: LoginScreen()),
      ),
    );
  }
}
