import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../services/cache_service.dart';

class SecurityScreen extends StatefulWidget {
  final CacheService cacheService;

  const SecurityScreen({super.key, required this.cacheService});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _encryptor = SimpleEncryptor('demo_secret_key');
  final _compressor = SimpleCompressor();
  String _rawStored = 'Nothing stored yet';
  String _recovered = 'Nothing recovered yet';

  Future<void> _storeEncrypted() async {
    final inner = MemoryCacheStorage();
    final secure = SecureCacheStorage(
      inner,
      encryptor: _encryptor,
      compressor: _compressor,
    );

    final entry = CacheEntry(
      data: 'Sensitive data: credit card 1234-5678-9012-3456',
      createdAt: DateTime.now(),
      ttl: const Duration(minutes: 5),
    );

    await secure.write('secret_key', entry);

    final rawEntry = await inner.read('secret_key');
    final rawText = rawEntry?.data.toString() ?? 'null';

    final recoveredEntry = await secure.read('secret_key') ?? CacheEntry(data: 'null', createdAt: DateTime.now(), ttl: const Duration(minutes: 5));

    setState(() {
      _rawStored = rawText;
      _recovered = recoveredEntry.data.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security Layer', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Encrypt + compress cache data with SecureCacheStorage',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _storeEncrypted,
              icon: const Icon(Icons.enhanced_encryption),
              label: const Text('Store & Recover Encrypted Data'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raw stored in Hive (encrypted):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _rawStored,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recovered after decrypt:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _recovered,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
