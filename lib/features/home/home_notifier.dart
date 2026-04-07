import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/mind_map.dart';
import '../../models/mind_node.dart';
import '../../models/node_style.dart';
import '../../services/local_storage_service.dart';

final _uuid = Uuid();
final _storageService = LocalStorageService();

class HomeState {
  final List<MindMap> mindMaps;
  final bool isLoading;

  const HomeState({required this.mindMaps, this.isLoading = false});

  HomeState copyWith({List<MindMap>? mindMaps, bool? isLoading}) {
    return HomeState(
      mindMaps: mindMaps ?? this.mindMaps,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState(mindMaps: [])) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      await _storageService.init();
      await loadMindMaps();
    } catch (e) {
      // Gracefully fall back to empty state on storage error
      state = state.copyWith(mindMaps: [], isLoading: false);
    }
  }

  Future<void> loadMindMaps() async {
    try {
      final maps = await _storageService.getAllMindMaps();
      state = state.copyWith(mindMaps: maps, isLoading: false);
    } catch (e) {
      state = state.copyWith(mindMaps: [], isLoading: false);
    }
  }

  Future<MindMap> createMindMap(String title) async {
    final rootNode = MindNode(
      id: _uuid.v4(),
      text: title,
      x: 400,
      y: 400,
      isRoot: true,
      style: const NodeStyle(), // default grey
    );

    final mindMap = MindMap(
      id: _uuid.v4(),
      title: title,
      nodes: [rootNode],
    );

    await _storageService.saveMindMap(mindMap);
    await loadMindMaps();
    return mindMap;
  }

  Future<void> deleteMindMap(String id) async {
    await _storageService.deleteMindMap(id);
    await loadMindMaps();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
