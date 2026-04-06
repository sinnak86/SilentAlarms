import 'package:flutter_test/flutter_test.dart';
import 'package:mindmap/models/mind_map.dart';
import 'package:mindmap/models/mind_node.dart';
import 'package:mindmap/models/mind_edge.dart';
import 'package:mindmap/services/layout_service.dart';

void main() {
  group('LayoutService', () {
    final service = LayoutService();

    MindMap _buildTestMap() {
      return MindMap(
        id: 'map-1',
        title: 'Test',
        nodes: [
          MindNode(id: 'root', text: 'Root', x: 500, y: 500, isRoot: true),
          MindNode(id: 'c1', text: 'Child 1', x: 0, y: 0, parentId: 'root'),
          MindNode(id: 'c2', text: 'Child 2', x: 0, y: 0, parentId: 'root'),
          MindNode(id: 'gc1', text: 'GC 1', x: 0, y: 0, parentId: 'c1'),
        ],
        edges: [
          MindEdge(id: 'e1', fromNodeId: 'root', toNodeId: 'c1'),
          MindEdge(id: 'e2', fromNodeId: 'root', toNodeId: 'c2'),
          MindEdge(id: 'e3', fromNodeId: 'c1', toNodeId: 'gc1'),
        ],
      );
    }

    test('radial layout places root at origin', () {
      final map = _buildTestMap();
      final nodes = service.applyRadialLayout(map);
      final root = nodes.firstWhere((n) => n.isRoot);

      expect(root.x, 0.0);
      expect(root.y, 0.0);
    });

    test('radial layout moves children away from root', () {
      final map = _buildTestMap();
      final nodes = service.applyRadialLayout(map);
      final root = nodes.firstWhere((n) => n.isRoot);
      final children = nodes.where((n) => n.parentId == 'root').toList();

      for (final child in children) {
        final dist = ((child.x - root.x) * (child.x - root.x) +
                (child.y - root.y) * (child.y - root.y))
            .abs();
        expect(dist, greaterThan(0));
      }
    });

    test('tree layout returns same node count', () {
      final map = _buildTestMap();
      final nodes = service.applyTreeLayout(map);
      expect(nodes.length, map.nodes.length);
    });

    test('handles empty map', () {
      final map = MindMap(id: 'm', title: 'Empty');
      final nodes = service.applyRadialLayout(map);
      expect(nodes.isEmpty, true);
    });
  });
}
