import 'package:flutter/material.dart';
import '../../models/mind_map.dart';

class ToolbarWidget extends StatelessWidget {
  final MindMap mindMap;
  final String? selectedNodeId;
  final VoidCallback onAddNodeLeft;
  final VoidCallback onAddNodeRight;
  final VoidCallback? onDeleteNode;
  final VoidCallback? onRenameNode;
  final VoidCallback onExport;

  const ToolbarWidget({
    super.key,
    required this.mindMap,
    required this.selectedNodeId,
    required this.onAddNodeLeft,
    required this.onAddNodeRight,
    required this.onDeleteNode,
    required this.onExport,
    this.onRenameNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selectedNodeId != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rename button
              FloatingActionButton.small(
                heroTag: 'rename',
                onPressed: onRenameNode,
                backgroundColor: const Color(0xFF007AFF),
                tooltip: '노드명 변경',
                child: const Icon(Icons.abc, size: 22),
              ),
              const SizedBox(width: 8),
              // Delete button
              FloatingActionButton.small(
                heroTag: 'delete',
                onPressed: onDeleteNode,
                backgroundColor: Colors.red,
                tooltip: '노드 삭제',
                child: const Icon(Icons.delete),
              ),
            ],
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
