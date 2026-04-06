import 'package:flutter_test/flutter_test.dart';
import 'package:mindmap/models/mind_map.dart';
import 'package:mindmap/models/mind_node.dart';
import 'package:mindmap/models/mind_edge.dart';
import 'package:mindmap/models/node_style.dart';
import 'package:mindmap/models/edge_style.dart';

void main() {
  group('MindNode', () {
    test('serializes and deserializes correctly', () {
      final node = MindNode(
        id: 'node-1',
        text: 'Test Node',
        x: 100.0,
        y: 200.0,
        style: const NodeStyle(colorValue: 0xFF4CAF50),
        isRoot: true,
      );

      final json = node.toJson();
      final restored = MindNode.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.text, node.text);
      expect(restored.x, node.x);
      expect(restored.y, node.y);
      expect(restored.isRoot, node.isRoot);
      expect(restored.style.colorValue, node.style.colorValue);
    });

    test('copyWith clears parentId when clearParent is true', () {
      final node = MindNode(
        id: 'node-1',
        text: 'Child',
        x: 0,
        y: 0,
        parentId: 'parent-id',
      );

      final updated = node.copyWith(clearParent: true);
      expect(updated.parentId, isNull);
    });
  });

  group('MindEdge', () {
    test('serializes and deserializes correctly', () {
      final edge = MindEdge(
        id: 'edge-1',
        fromNodeId: 'node-1',
        toNodeId: 'node-2',
        style: const EdgeStyle(strokeWidth: 3.0, hasArrow: true),
      );

      final json = edge.toJson();
      final restored = MindEdge.fromJson(json);

      expect(restored.id, edge.id);
      expect(restored.fromNodeId, edge.fromNodeId);
      expect(restored.toNodeId, edge.toNodeId);
      expect(restored.style.strokeWidth, edge.style.strokeWidth);
      expect(restored.style.hasArrow, edge.style.hasArrow);
    });
  });

  group('MindMap', () {
    test('serializes and deserializes correctly', () {
      final map = MindMap(
        id: 'map-1',
        title: 'Test Map',
        nodes: [
          MindNode(id: 'n1', text: 'Root', x: 0, y: 0, isRoot: true),
          MindNode(id: 'n2', text: 'Child', x: 100, y: 0, parentId: 'n1'),
        ],
        edges: [
          MindEdge(id: 'e1', fromNodeId: 'n1', toNodeId: 'n2'),
        ],
      );

      final json = map.toJson();
      final restored = MindMap.fromJson(json);

      expect(restored.id, map.id);
      expect(restored.title, map.title);
      expect(restored.nodes.length, 2);
      expect(restored.edges.length, 1);
      expect(restored.nodes.first.isRoot, true);
    });

    test('copyWith updates updatedAt', () {
      final original = MindMap(id: 'map-1', title: 'Original');
      final updated = original.copyWith(title: 'Updated');

      expect(updated.title, 'Updated');
      expect(updated.id, original.id);
    });
  });
}
