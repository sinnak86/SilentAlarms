import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/mind_map.dart';
import '../../models/mind_node.dart';
import '../../models/mind_edge.dart';
import '../../models/node_style.dart';
import '../../services/local_storage_service.dart';
import '../../services/layout_service.dart';

final _uuid = Uuid();
final _storageService = LocalStorageService();
final _layoutService = LayoutService();

class CanvasState {
  final MindMap mindMap;
  final String? selectedNodeId;
  final String? connectingFromNodeId;
  final bool isDirty;

  const CanvasState({
    required this.mindMap,
    this.selectedNodeId,
    this.connectingFromNodeId,
    this.isDirty = false,
  });

  CanvasState copyWith({
    MindMap? mindMap,
    String? selectedNodeId,
    String? connectingFromNodeId,
    bool clearSelection = false,
    bool clearConnecting = false,
    bool? isDirty,
  }) {
    return CanvasState(
      mindMap: mindMap ?? this.mindMap,
      selectedNodeId: clearSelection ? null : selectedNodeId ?? this.selectedNodeId,
      connectingFromNodeId:
          clearConnecting ? null : connectingFromNodeId ?? this.connectingFromNodeId,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier(MindMap initialMap)
      : super(CanvasState(mindMap: initialMap));

  // ─── Node Operations ───────────────────────────────────────────────────────

  void addNode({double x = 0, double y = 0, String? parentId}) {
    final node = MindNode(
      id: _uuid.v4(),
      text: 'New Idea',
      x: x,
      y: y,
      parentId: parentId,
      style: NodeStyle(colorValue: NodeStyle.presetColors[
          state.mindMap.nodes.length % NodeStyle.presetColors.length]),
    );

    final updatedMap = state.mindMap.copyWith(
      nodes: [...state.mindMap.nodes, node],
    );

    // Auto-add edge if has parent
    MindMap finalMap = updatedMap;
    if (parentId != null) {
      final edge = MindEdge(
        id: _uuid.v4(),
        fromNodeId: parentId,
        toNodeId: node.id,
      );
      finalMap = updatedMap.copyWith(
        edges: [...updatedMap.edges, edge],
      );
    }

    state = state.copyWith(
      mindMap: finalMap,
      selectedNodeId: node.id,
      isDirty: true,
    );
  }

  void updateNodeText(String nodeId, String text) {
    final nodes = state.mindMap.nodes.map((n) {
      return n.id == nodeId ? n.copyWith(text: text) : n;
    }).toList();
    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: nodes),
      isDirty: true,
    );
  }

  void moveNode(String nodeId, double dx, double dy) {
    final nodes = state.mindMap.nodes.map((n) {
      return n.id == nodeId ? n.copyWith(x: n.x + dx, y: n.y + dy) : n;
    }).toList();
    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: nodes),
      isDirty: true,
    );
  }

  void deleteNode(String nodeId) {
    // Remove node and all connected edges
    final nodes = state.mindMap.nodes.where((n) => n.id != nodeId).toList();
    final edges = state.mindMap.edges
        .where((e) => e.fromNodeId != nodeId && e.toNodeId != nodeId)
        .toList();

    // Also update children to remove parentId
    final updatedNodes = nodes.map((n) {
      return n.parentId == nodeId ? n.copyWith(clearParent: true) : n;
    }).toList();

    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: updatedNodes, edges: edges),
      clearSelection: true,
      isDirty: true,
    );
  }

  void updateNodeStyle(String nodeId, NodeStyle style) {
    final nodes = state.mindMap.nodes.map((n) {
      return n.id == nodeId ? n.copyWith(style: style) : n;
    }).toList();
    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: nodes),
      isDirty: true,
    );
  }

  // ─── Edge Operations ───────────────────────────────────────────────────────

  void connectNodes(String fromId, String toId) {
    // Prevent duplicate edges
    final exists = state.mindMap.edges.any(
      (e) => e.fromNodeId == fromId && e.toNodeId == toId,
    );
    if (exists || fromId == toId) {
      state = state.copyWith(clearConnecting: true);
      return;
    }

    final edge = MindEdge(
      id: _uuid.v4(),
      fromNodeId: fromId,
      toNodeId: toId,
    );

    state = state.copyWith(
      mindMap: state.mindMap.copyWith(
        edges: [...state.mindMap.edges, edge],
      ),
      clearConnecting: true,
      isDirty: true,
    );
  }

  void startConnecting(String nodeId) {
    state = state.copyWith(connectingFromNodeId: nodeId);
  }

  void cancelConnecting() {
    state = state.copyWith(clearConnecting: true);
  }

  // ─── Selection ─────────────────────────────────────────────────────────────

  void selectNode(String? nodeId) {
    state = state.copyWith(
      selectedNodeId: nodeId,
      clearSelection: nodeId == null,
    );
  }

  void deselectAll() {
    state = state.copyWith(clearSelection: true, clearConnecting: true);
  }

  // ─── Layout ────────────────────────────────────────────────────────────────

  void applyRadialLayout() {
    final newNodes = _layoutService.applyRadialLayout(state.mindMap);
    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: newNodes),
      isDirty: true,
    );
  }

  void applyTreeLayout() {
    final newNodes = _layoutService.applyTreeLayout(state.mindMap);
    state = state.copyWith(
      mindMap: state.mindMap.copyWith(nodes: newNodes),
      isDirty: true,
    );
  }

  // ─── Persistence ───────────────────────────────────────────────────────────

  Future<void> save() async {
    await _storageService.saveMindMap(state.mindMap);
    state = state.copyWith(isDirty: false);
  }
}

// Providers
final canvasProvider =
    StateNotifierProvider.family<CanvasNotifier, CanvasState, MindMap>(
  (ref, mindMap) => CanvasNotifier(mindMap),
);
