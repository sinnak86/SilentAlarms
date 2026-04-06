import 'package:flutter/material.dart';
import '../../models/mind_node.dart';
import '../../models/node_style.dart';

class NodeEditorDialog extends StatefulWidget {
  final MindNode node;
  final void Function(String text, NodeStyle style) onSave;
  final VoidCallback onDelete;

  const NodeEditorDialog({
    super.key,
    required this.node,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<NodeEditorDialog> {
  late TextEditingController _textController;
  late NodeStyle _style;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.node.text);
    _style = widget.node.style;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Node'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Node Text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: NodeStyle.presetColors.map((colorValue) {
                final isSelected = _style.colorValue == colorValue;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _style = _style.copyWith(colorValue: colorValue);
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2.5)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Shape', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Rect')),
                ButtonSegment(value: 1, label: Text('Round')),
                ButtonSegment(value: 2, label: Text('Oval')),
                ButtonSegment(value: 3, label: Text('♦')),
              ],
              selected: {_style.shapeIndex},
              onSelectionChanged: (selected) {
                setState(() {
                  _style = _style.copyWith(shapeIndex: selected.first);
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDelete();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSave(_textController.text.trim(), _style);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
