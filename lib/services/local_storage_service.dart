import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mind_map.dart';

class LocalStorageService {
  static const String _prefix = 'mindmap_';
  static const String _keysKey = 'mindmap_keys';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<List<MindMap>> getAllMindMaps() async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_keysKey) ?? [];
    final maps = <MindMap>[];
    for (final key in keys) {
      final jsonStr = prefs.getString('$_prefix$key');
      if (jsonStr != null) {
        try {
          maps.add(MindMap.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    maps.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return maps;
  }

  Future<MindMap?> getMindMap(String id) async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString('$_prefix$id');
    if (jsonStr == null) return null;
    try {
      return MindMap.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMindMap(MindMap mindMap) async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_keysKey) ?? [];
    if (!keys.contains(mindMap.id)) {
      keys.add(mindMap.id);
      await prefs.setStringList(_keysKey, keys);
    }
    await prefs.setString('$_prefix${mindMap.id}', jsonEncode(mindMap.toJson()));
  }

  Future<void> deleteMindMap(String id) async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_keysKey) ?? [];
    keys.remove(id);
    await prefs.setStringList(_keysKey, keys);
    await prefs.remove('$_prefix$id');
  }
}
