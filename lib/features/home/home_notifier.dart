import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/mind_map.dart';
import '../../models/mind_node.dart';
import '../../models/mind_folder.dart';
import '../../models/node_style.dart';
import '../../services/local_storage_service.dart';

final _uuid = Uuid();
final _storageService = LocalStorageService();

class HomeState {
  final List<MindFolder> folders;
  final List<MindMap> mindMaps;
  final String? focusedFolderId;
  final String? focusedMapId;
  final bool isLoading;

  const HomeState({
    this.folders = const [],
    this.mindMaps = const [],
    this.focusedFolderId,
    this.focusedMapId,
    this.isLoading = false,
  });

  HomeState copyWith({
    List<MindFolder>? folders,
    List<MindMap>? mindMaps,
    String? focusedFolderId,
    bool clearFocus = false,
    String? focusedMapId,
    bool clearMapFocus = false,
    bool? isLoading,
  }) {
    return HomeState(
      folders: folders ?? this.folders,
      mindMaps: mindMaps ?? this.mindMaps,
      focusedFolderId: clearFocus ? null : (focusedFolderId ?? this.focusedFolderId),
      focusedMapId: clearMapFocus ? null : (focusedMapId ?? this.focusedMapId),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _storageService.init();
      final defaultId = await _storageService.ensureDefaultFolderAndMigrate();
      final folders = await _storageService.getAllFolders();
      final maps = await _storageService.getAllMindMaps();
      state = HomeState(
        folders: folders,
        mindMaps: maps,
        focusedFolderId: defaultId,
        isLoading: false,
      );
    } catch (_) {
      state = const HomeState(isLoading: false);
    }
  }

  Future<void> loadAll() async {
    try {
      final folders = await _storageService.getAllFolders();
      final maps = await _storageService.getAllMindMaps();
      state = state.copyWith(folders: folders, mindMaps: maps, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleFolderFocus(String folderId) {
    if (state.focusedFolderId == folderId) {
      state = state.copyWith(clearFocus: true, clearMapFocus: true);
    } else {
      state = state.copyWith(focusedFolderId: folderId, clearMapFocus: true);
    }
  }

  void toggleMapFocus(String mapId) {
    if (state.focusedMapId == mapId) {
      state = state.copyWith(clearMapFocus: true);
    } else {
      state = state.copyWith(focusedMapId: mapId);
    }
  }

  static const int maxFolders = 9;

  Future<MindFolder> createFolder(String name) async {
    if (state.folders.length >= maxFolders) return state.folders.first;
    final folder = MindFolder(
      id: _uuid.v4(),
      name: name,
      parentId: null,
      createdAt: DateTime.now(),
    );
    await _storageService.saveFolder(folder);
    await loadAll();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final folder = state.folders.firstWhere((f) => f.id == id);
    await _storageService.saveFolder(folder.copyWith(name: name));
    await loadAll();
  }

  Future<void> updateFolderColor(String id, int colorValue) async {
    final folder = state.folders.firstWhere((f) => f.id == id);
    await _storageService.saveFolder(folder.copyWith(colorValue: colorValue));
    await loadAll();
  }

  Future<void> deleteFolder(String id) async {
    // Delete all maps in this folder first
    final mapsInFolder = state.mindMaps.where((m) => m.folderId == id);
    for (final m in mapsInFolder) {
      await _storageService.deleteMindMap(m.id);
    }
    await _storageService.deleteFolder(id);
    if (state.focusedFolderId == id) {
      state = state.copyWith(clearFocus: true);
    }
    await loadAll();
  }

  Future<MindMap> createMindMap(String title) async {
    // Use focused folder, fall back to "기본" folder
    String? targetFolderId = state.focusedFolderId;
    if (targetFolderId == null) {
      final defaultFolder = state.folders
          .where((f) => f.parentId == null && f.name == '기본')
          .firstOrNull;
      targetFolderId = defaultFolder?.id;
    }

    final rootNode = MindNode(
      id: _uuid.v4(),
      text: title,
      x: 400,
      y: 400,
      isRoot: true,
      style: const NodeStyle(),
    );

    final mindMap = MindMap(
      id: _uuid.v4(),
      title: title,
      nodes: [rootNode],
      folderId: targetFolderId,
    );

    await _storageService.saveMindMap(mindMap);
    await loadAll();
    return mindMap;
  }

  Future<void> moveMapToFolder(String mapId, String folderId) async {
    final map = state.mindMaps.firstWhere((m) => m.id == mapId);
    await _storageService.saveMindMap(map.copyWith(folderId: folderId));
    await loadAll();
  }

  Future<void> deleteMindMap(String id) async {
    await _storageService.deleteMindMap(id);
    if (state.focusedMapId == id) {
      state = state.copyWith(clearMapFocus: true);
    }
    await loadAll();
  }

  /// Imports a map (from JSON backup) into the "기본" folder with a fresh ID.
  Future<void> importMapToDefaultFolder(MindMap importedMap) async {
    String? defaultFolderId = state.folders
        .where((f) => f.parentId == null && f.name == '기본')
        .firstOrNull
        ?.id;
    defaultFolderId ??=
        await _storageService.ensureDefaultFolderAndMigrate();

    final newMap = importedMap.copyWith(
      id: _uuid.v4(),
      folderId: defaultFolderId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _storageService.saveMindMap(newMap);
    await loadAll();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
