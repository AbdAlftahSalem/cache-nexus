import 'package:hive_flutter/hive_flutter.dart';
import 'cache_entry.dart';
import 'cache_storage.dart';

class HiveCacheStorage implements CacheStorage {
  final String boxName;
  Box? _box;

  HiveCacheStorage({this.boxName = 'smart_cache'});

  Future<void> init({bool initHive = true}) async {
    if (initHive) {
      await Hive.initFlutter();
    }
    _box = await Hive.openBox(boxName);
  }

  Box get box {
    if (_box == null) throw Exception('HiveCacheStorage not initialized. Call init() first.');
    return _box!;
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    await box.put(key, entry.toJson());
  }

  @override
  Future<CacheEntry?> read(String key) async {
    final data = box.get(key);
    if (data == null) return null;
    
    try {
      final json = Map<String, dynamic>.from(data as Map);
      return CacheEntry.fromJson(json);
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
  Future<void> clear() async {
    await box.clear();
  }
}
