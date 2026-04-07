import 'package:flutter/material.dart';
import '../../models/mind_map.dart';

class ToolbarWidget extends StatelessWidget {
  final MindMap mindMap;
  final String? selectedNodeId;
  final VoidCallback onAddNodeLeft;
  final VoidCallback onAddNodeRight;
  final VoidCallback? onDeleteNode;
  final VoidCallback onExport;

  const ToolbarWidget({
    super.key,
    required this.mindMap,
    required this.selectedNodeId,
    required this.onAddNodeLeft,
    required this.onAddNodeRight,
    required this.onDeleteNode,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selectedNodeId != null && onDeleteNode != null) ...[
          FloatingActionButton.small(
            heroTag: 'delete',
            onPressed: onDeleteNode,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'addLeft',
              onPressed: onAddNodeLeft,
              tooltip: '왼쪽에 노드 추가',
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'addRight',
              onPressed: onAddNodeRight,
              tooltip: '오른쪽에 노드 추가',
              child: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }
}
