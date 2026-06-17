import 'package:hive_flutter/hive_flutter.dart';
import 'cache_entry.dart';
import 'cache_storage.dart';

class HiveCacheStorage implements CacheStorage {
  final String boxName;
  Box<dynamic>? _box;

  HiveCacheStorage({this.boxName = 'smart_cache'});

  Future<void> init({bool initHive = true}) async {
    if (initHive) {
      await Hive.initFlutter();
    }
    _box = await Hive.openBox(boxName);
  }

  Box<dynamic> get box {
    if (_box == null) throw Exception('HiveCacheStorage not initialized. Call init() first.');
    return _box!;
  }

  @override
  Future<void> write(String key, CacheEntry<dynamic> entry) async {
    await box.put(key, entry.toJson());
  }

  @override
  Future<CacheEntry<dynamic>?> read(String key) async {
    final data = box.get(key);
    if (data == null) return null;

    try {
      final json = Map<String, dynamic>.from(data as Map);
      // Construct CacheEntry directly instead of using fromJson.
      // fromJson does `json['data'] as T` which fails for complex types
      // (e.g. List<Product>) because Hive deserializes to raw Maps/lists.
      return CacheEntry(
        data: json['data'],
        createdAt: DateTime.parse(json['createdAt'] as String),
        ttl: json['ttl'] != null
            ? Duration(milliseconds: json['ttl'] as int)
            : null,
      );
    } catch (e) {
      // If corrupted, delete it
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    await box.delete(key);
  }

  @override
  Future<void> deleteByPrefix(String prefix) async {
    final keysToDelete = box.keys.where((key) => key.toString().startsWith(prefix)).toList();
    await box.deleteAll(keysToDelete);
  }

  @override
  Future<void> clear() async {
    await box.clear();
  }
}
