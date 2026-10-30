import 'dart:convert';

import 'package:archive/archive.dart';

/// Compresses the serialized cache entries stored by
/// [SecureCacheStorage](package:cache_nexus/cache_nexus.dart).
abstract class CacheCompressor {
  /// Compresses [data].
  String compress(String data);

  /// Reverses [compress].
  String decompress(String data);
}

/// Stores data uncompressed.
class NoOpCompressor implements CacheCompressor {
  /// Creates the no-op compressor.
  const NoOpCompressor();

  @override
  String compress(String data) => data;

  @override
  String decompress(String data) => data;
}

/// Real GZip compression (pure Dart, works on every platform including web).
///
/// Compressed values are base64-encoded, so very small strings would grow;
/// values that do not get smaller are stored as they are. JSON payloads of a
/// few hundred bytes and up typically shrink by 60-90 %.
class GZipCompressor implements CacheCompressor {
  /// Creates a GZip compressor.
  const GZipCompressor();

  static const String _gzipPrefix = 'gz1:';
  static const String _rawPrefix = 'raw1:';

  @override
  String compress(String data) {
    final packed =
        '$_gzipPrefix${base64Encode(const GZipEncoder().encodeBytes(utf8.encode(data)))}';
    if (packed.length < data.length) return packed;
    // Not worth it. Mark the value only when it could be mistaken for ours.
    if (data.startsWith(_gzipPrefix) ||
        data.startsWith(_rawPrefix) ||
        data.startsWith(SimpleCompressor._legacyPrefix)) {
      return '$_rawPrefix$data';
    }
    return data;
  }

  @override
  String decompress(String data) {
    if (data.startsWith(_gzipPrefix)) {
      final bytes = base64Decode(data.substring(_gzipPrefix.length));
      return utf8.decode(const GZipDecoder().decodeBytes(bytes));
    }
    if (data.startsWith(_rawPrefix)) return data.substring(_rawPrefix.length);
    return data;
  }
}

/// A [GZipCompressor] that can also read values written by the 1.0.x
/// `SimpleCompressor` (which only added a `COMPRESSED:` marker).
///
/// Since 1.1.0 it compresses for real. New code should use
/// [GZipCompressor].
class SimpleCompressor extends GZipCompressor {
  /// Creates the compressor.
  const SimpleCompressor();

  static const String _legacyPrefix = 'COMPRESSED:';

  @override
  String decompress(String data) {
    if (data.startsWith(_legacyPrefix)) {
      return data.substring(_legacyPrefix.length);
    }
    return super.decompress(data);
  }
}
