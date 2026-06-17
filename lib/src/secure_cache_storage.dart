import 'dart:convert';
import 'cache_storage.dart';
import 'cache_entry.dart';
import 'cache_encryptor.dart';
import 'cache_compressor.dart';

class SecureCacheStorage implements CacheStorage {
  final CacheStorage _inner;
  final CacheEncryptor encryptor;
  final CacheCompressor compressor;

  SecureCacheStorage(
    this._inner, {
    CacheEncryptor? encryptor,
    CacheCompressor? compressor,
  })  : encryptor = encryptor ?? NoOpEncryptor(),
        compressor = compressor ?? NoOpCompressor();

  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) async {
    // 1. Serialize entire entry to JSON
    final jsonString = jsonEncode(entry.toJson());
    
    // 2. Compress
    final compressed = compressor.compress(jsonString);
    
    // 3. Encrypt
    final encrypted = encryptor.encrypt(compressed);

    // 4. Store as a single blob in a wrapper CacheEntry
    // We use a dummy entry to satisfy the _inner storage interface
    final secureEntry = CacheEntry<String>(
      data: encrypted,
      createdAt: entry.createdAt, // We keep these for internal tracking if needed, 
                                  // but the actual data is hidden.
      ttl: entry.ttl,
    );
    
    await _inner.write(key, secureEntry);
  }

  @override
  Future<CacheEntry<dynamic>?> read(String key) async {
    final secureEntry = await _inner.read(key);
    if (secureEntry == null) return null;

    try {
      final encrypted = secureEntry.data as String;
      
      // 1. Decrypt
      final decrypted = encryptor.decrypt(encrypted);
      
      // 2. Decompress
      final decompressed = compressor.decompress(decrypted);
      
      // 3. Deserialize
      final json = jsonDecode(decompressed) as Map<String, dynamic>;
      return CacheEntry.fromJson(json);
    } catch (e) {
      // If decryption or decompression fails, it might be corrupted or not encrypted
      // Fallback: return null or try to return the raw entry if it was previously unencrypted
      return null;
    }
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> deleteByPrefix(String prefix) => _inner.deleteByPrefix(prefix);

  @override
  Future<void> clear() => _inner.clear();
}
