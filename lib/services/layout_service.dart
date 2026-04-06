import 'dart:math';
import '../models/mind_map.dart';
import '../models/mind_node.dart';
import '../shared/constants.dart';

class LayoutService {
  /// Applies radial layout to the mind map starting from the root node.
  /// Returns a new list of nodes with updated positions.
  List<MindNode> applyRadialLayout(MindMap mindMap) {
    if (mindMap.nodes.isEmpty) return mindMap.nodes;

    final root = mindMap.nodes.firstWhere(
      (n) => n.isRoot,
      orElse: () => mindMap.nodes.first,
    );

    final nodeMap = {for (final n in mindMap.nodes) n.id: n};
    final updatedNodes = <String, MindNode>{};

    // Place root in center
    updatedNodes[root.id] = root.copyWith(x: 0, y: 0);

    // Build children map
    final childrenMap = <String, List<String>>{};
    for (final node in mindMap.nodes) {
      if (node.parentId != null) {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node.id);
      }
    }

    // BFS layout
    _layoutChildren(
      parentId: root.id,
      childrenMap: childrenMap,
      nodeMap: nodeMap,
      updatedNodes: updatedNodes,
      startAngle: 0,
      angleRange: 2 * pi,
      radius: AppConstants.radialSpacing,
      depth: 1,
    );

    // Preserve positions for nodes not in tree (disconnected)
    for (final node in mindMap.nodes) {
      if (!updatedNodes.containsKey(node.id)) {
        updatedNodes[node.id] = node;
      }
    }

    return mindMap.nodes
        .map((n) => updatedNodes[n.id] ?? n)
        .toList();
  }

  void _layoutChildren({
    required String parentId,
    required Map<String, List<String>> childrenMap,
    required Map<String, MindNode> nodeMap,
    required Map<String, MindNode> updatedNodes,
    required double startAngle,
    required double angleRange,
    required double radius,
    required int depth,
  }) {
    final children = childrenMap[parentId] ?? [];
    if (children.isEmpty) return;

    final parent = updatedNodes[parentId];
    if (parent == null) return;

    final angleStep = angleRange / children.length;

    for (int i = 0; i < children.length; i++) {
      final childId = children[i];
      final angle = startAngle + angleStep * i + angleStep / 2;
      final x = parent.x + radius * cos(angle);
      final y = parent.y + radius * sin(angle);

      final child = nodeMap[childId];
      if (child != null) {
        updatedNodes[childId] = child.copyWith(x: x, y: y);
        _layoutChildren(
          parentId: childId,
          childrenMap: childrenMap,
          nodeMap: nodeMap,
          updatedNodes: updatedNodes,
          startAngle: angle - angleStep / 2,
          angleRange: angleStep,
          radius: AppConstants.radialSpacing * (0.8 - depth * 0.1).clamp(0.4, 0.8),
          depth: depth + 1,
        );
      }
    }
  }

  /// Simple tree layout (left-to-right hierarchy)
  List<MindNode> applyTreeLayout(MindMap mindMap) {
    if (mindMap.nodes.isEmpty) return mindMap.nodes;

    final root = mindMap.nodes.firstWhere(
      (n) => n.isRoot,
      orElse: () => mindMap.nodes.first,
    );

    final nodeMap = {for (final n in mindMap.nodes) n.id: n};
    final childrenMap = <String, List<String>>{};
    for (final node in mindMap.nodes) {
      if (node.parentId != null) {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node.id);
      }
    }

    final updatedNodes = <String, MindNode>{};
    final counter = [0]; // Use list for mutable reference in recursive call

    _treeLayoutDFS(
      nodeId: root.id,
      depth: 0,
      nodeMap: nodeMap,
      childrenMap: childrenMap,
      updatedNodes: updatedNodes,
      counter: counter,
    );

    for (final node in mindMap.nodes) {
      if (!updatedNodes.containsKey(node.id)) {
        updatedNodes[node.id] = node;
      }
    }

    return mindMap.nodes.map((n) => updatedNodes[n.id] ?? n).toList();
  }

  void _treeLayoutDFS({
    required String nodeId,
    required int depth,
    required Map<String, MindNode> nodeMap,
    required Map<String, List<String>> childrenMap,
    required Map<String, MindNode> updatedNodes,
    required List<int> counter,
  }) {
    final children = childrenMap[nodeId] ?? [];
    final node = nodeMap[nodeId];
    if (node == null) return;

    final x = depth * AppConstants.levelSpacing;
    final y = counter[0] * AppConstants.siblingSpacing;
    updatedNodes[nodeId] = node.copyWith(x: x, y: y);
    counter[0]++;

    for (final childId in children) {
      _treeLayoutDFS(
        nodeId: childId,
        depth: depth + 1,
        nodeMap: nodeMap,
        childrenMap: childrenMap,
        updatedNodes: updatedNodes,
        counter: counter,
      );
    }
  }
}
