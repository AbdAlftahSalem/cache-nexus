abstract class CacheEncryptor {
  String encrypt(String data);
  String decrypt(String data);
}

class NoOpEncryptor implements CacheEncryptor {
  @override
  String encrypt(String data) => data;

  @override
  String decrypt(String data) => data;
}

/// A simple XOR-based encryptor for demonstration purposes.
/// For production, use a more secure algorithm like AES.
class SimpleEncryptor implements CacheEncryptor {
  final String key;

  SimpleEncryptor(this.key);

  @override
  String encrypt(String data) {
    final bytes = data.codeUnits;
    final keyBytes = key.codeUnits;
    final result = List<int>.filled(bytes.length, 0);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }
    // Using simple mapping to avoid issues with non-printable characters in some storages
    // In real scenarios, Base64 is preferred.
    return result.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  String decrypt(String data) {
    final bytes = <int>[];
    for (var i = 0; i < data.length; i += 2) {
      bytes.add(int.parse(data.substring(i, i + 2), radix: 16));
    }
    final keyBytes = key.codeUnits;
    final result = List<int>.filled(bytes.length, 0);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return String.fromCharCodes(result);
  }
}
