import 'package:flutter/material.dart';
import '../../models/mind_map.dart';

class ToolbarWidget extends StatelessWidget {
  final MindMap mindMap;
  final String? selectedNodeId;
  final VoidCallback onAddNode;
  final VoidCallback? onDeleteNode;
  final VoidCallback onExport;

  const ToolbarWidget({
    super.key,
    required this.mindMap,
    required this.selectedNodeId,
    required this.onAddNode,
    required this.onDeleteNode,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedNodeId != null && onDeleteNode != null)
          FloatingActionButton.small(
            heroTag: 'delete',
            onPressed: onDeleteNode,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
          ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: onAddNode,
          tooltip: selectedNodeId != null ? 'Add child node' : 'Add node',
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
