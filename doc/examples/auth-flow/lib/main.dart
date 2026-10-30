import 'package:flutter/material.dart';
import 'package:cache_nexus/cache_nexus.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache
  final cache = CacheNexusManager(
    memoryStorage: MemoryCacheStorage(),
    // Demo: a fresh key per launch, so nothing survives a restart. In a real
    // app load the key from flutter_secure_storage and wrap HiveCacheStorage.
    persistentStorage: SecureCacheStorage(
      MemoryCacheStorage(),
      encryptor: AesGcmEncryptor(AesGcmEncryptor.generateKey()),
      compressor: const GZipCompressor(),
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
      builder: (context, child) =>
          CacheNexusOverlay(manager: cache, child: child!),
      home: AuthService(cache: cache, child: LoginScreen()),
    );
  }
}
