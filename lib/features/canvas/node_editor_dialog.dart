import 'dart:ui';
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Node',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Node Text',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Color',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.maxFinite,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: NodeStyle.presetColors.map((colorValue) {
                        final isSelected = _style.colorValue == colorValue;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _style = _style.copyWith(colorValue: colorValue)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(
                                      color: Colors.transparent, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(colorValue).withValues(alpha: 0.4),
                                  blurRadius: isSelected ? 12 : 4,
                                  spreadRadius: isSelected ? 2 : 0,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Shape',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.maxFinite,
                    child: SegmentedButton<int>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        selectedBackgroundColor: const Color(0xFF007AFF),
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Rect')),
                        ButtonSegment(value: 1, label: Text('Round')),
                        ButtonSegment(value: 2, label: Text('Oval')),
                        ButtonSegment(value: 3, label: Text('◆')),
                      ],
                      selected: {_style.shapeIndex},
                      onSelectionChanged: (selected) => setState(
                          () => _style =
                              _style.copyWith(shapeIndex: selected.first)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDelete();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSave(_textController.text.trim(), _style);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
