import 'dart:math' show pi;
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
                  // ── Icon-based shape picker (fixed size, no layout shift) ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        _ShapeButton(
                          shapeIndex: i,
                          isSelected: _style.shapeIndex == i,
                          onTap: () => setState(
                              () => _style = _style.copyWith(shapeIndex: i)),
                        ),
                      ],
                    ],
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

// ── Shape picker button (fixed 52×52, draws the shape icon inside) ────────────

class _ShapeButton extends StatelessWidget {
  final int shapeIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShapeButton({
    required this.shapeIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(child: _buildIcon()),
      ),
    );
  }

  Widget _buildIcon() {
    final stroke = isSelected ? Colors.white : Colors.grey.shade600;
    switch (shapeIndex) {
      case 0: // Rectangle
        return Container(
          width: 30,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: stroke, width: 2),
          ),
        );
      case 1: // Rounded rectangle
        return Container(
          width: 30,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: stroke, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      case 2: // Oval
        return Container(
          width: 32,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: stroke, width: 2),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      case 3: // Diamond
        return Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: stroke, width: 2),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
