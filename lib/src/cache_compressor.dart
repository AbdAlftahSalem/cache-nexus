abstract class CacheCompressor {
  String compress(String data);
  String decompress(String data);
}

class NoOpCompressor implements CacheCompressor {
  @override
  String compress(String data) => data;

  @override
  String decompress(String data) => data;
}

/// A mock compressor that simulates compression by prefixing data.
/// In a real application, use a library like 'archive' for GZip/LZip.
class SimpleCompressor implements CacheCompressor {
  static const _prefix = 'COMPRESSED:';

  @override
  String compress(String data) {
    // Mock: only "compress" if data is large enough
    if (data.length > 100) {
      return '$_prefix$data';
    }
    return data;
  }

  @override
  String decompress(String data) {
    if (data.startsWith(_prefix)) {
      return data.substring(_prefix.length);
    }
    return data;
  }
}
