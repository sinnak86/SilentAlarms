import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/mind_map.dart';
import '../models/mind_folder.dart';

class LocalStorageService {
  static const String _prefix = 'mindmap_';
  static const String _keysKey = 'mindmap_keys';
  static const String _folderPrefix = 'mindfolder_';
  static const String _folderKeysKey = 'mindfolder_keys';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── MindMap CRUD ──────────────────────────────────────────────────────────

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

  // ─── Folder CRUD ───────────────────────────────────────────────────────────

  Future<List<MindFolder>> getAllFolders() async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_folderKeysKey) ?? [];
    final folders = <MindFolder>[];
    for (final key in keys) {
      final jsonStr = prefs.getString('$_folderPrefix$key');
      if (jsonStr != null) {
        try {
          folders.add(MindFolder.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    folders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return folders;
  }

  Future<void> saveFolder(MindFolder folder) async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_folderKeysKey) ?? [];
    if (!keys.contains(folder.id)) {
      keys.add(folder.id);
      await prefs.setStringList(_folderKeysKey, keys);
    }
    await prefs.setString('$_folderPrefix${folder.id}', jsonEncode(folder.toJson()));
  }

  Future<void> deleteFolder(String id) async {
    final prefs = await _getPrefs();
    final keys = prefs.getStringList(_folderKeysKey) ?? [];
    keys.remove(id);
    await prefs.setStringList(_folderKeysKey, keys);
    await prefs.remove('$_folderPrefix$id');
  }

  // ─── Migration ─────────────────────────────────────────────────────────────

  /// Ensures "기본" default folder exists and migrates orphan maps into it.
  /// Returns the default folder id. Idempotent.
  Future<String> ensureDefaultFolderAndMigrate() async {
    final folders = await getAllFolders();

    // Find or create the "기본" root folder
    MindFolder defaultFolder;
    final existing = folders.where((f) => f.parentId == null && f.name == '기본').toList();
    if (existing.isNotEmpty) {
      defaultFolder = existing.first;
    } else {
      defaultFolder = MindFolder(
        id: const Uuid().v4(),
        name: '기본',
        createdAt: DateTime.now(),
      );
      await saveFolder(defaultFolder);
    }

    // Migrate maps that have no folderId
    final maps = await getAllMindMaps();
    for (final map in maps) {
      if (map.folderId == null) {
        await saveMindMap(map.copyWith(folderId: defaultFolder.id));
      }
    }

    return defaultFolder.id;
  }
}
