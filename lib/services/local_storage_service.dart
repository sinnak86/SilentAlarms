import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/mind_map.dart';
import '../shared/constants.dart';

class LocalStorageService {
  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(AppConstants.mindMapsBox);
  }

  Future<List<MindMap>> getAllMindMaps() async {
    final maps = <MindMap>[];
    for (final key in _box.keys) {
      final jsonStr = _box.get(key) as String?;
      if (jsonStr != null) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          maps.add(MindMap.fromJson(json));
        } catch (_) {
          // Skip corrupted entries
        }
      }
    }
    maps.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return maps;
  }

  Future<MindMap?> getMindMap(String id) async {
    final jsonStr = _box.get(id) as String?;
    if (jsonStr == null) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MindMap.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMindMap(MindMap mindMap) async {
    final jsonStr = jsonEncode(mindMap.toJson());
    await _box.put(mindMap.id, jsonStr);
  }

  Future<void> deleteMindMap(String id) async {
    await _box.delete(id);
  }

  Future<void> close() async {
    await _box.close();
  }
}
