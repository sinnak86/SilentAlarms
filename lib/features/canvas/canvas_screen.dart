import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../models/mind_map.dart';
import '../../models/mind_node.dart';
import '../../shared/constants.dart';
import 'canvas_notifier.dart';
import 'canvas_painter.dart';
import 'node_editor_dialog.dart';
import 'toolbar_widget.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final MindMap mindMap;

  const CanvasScreen({super.key, required this.mindMap});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider(widget.mindMap));
    final notifier = ref.read(canvasProvider(widget.mindMap).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(canvasState.mindMap.title),
        actions: [
          if (canvasState.isDirty)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: () => notifier.save(),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'radial':
                  notifier.applyRadialLayout();
                case 'tree':
                  notifier.applyTreeLayout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'radial', child: Text('Radial Layout')),
              PopupMenuItem(value: 'tree', child: Text('Tree Layout')),
            ],
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _repaintKey,
        child: GestureDetector(
          onTapUp: (details) {
            final pos = _toCanvasPosition(details.localPosition);
            final tappedNode = _findNodeAt(pos, canvasState.mindMap.nodes);

            if (tappedNode != null) {
              if (canvasState.connectingFromNodeId != null) {
                notifier.connectNodes(
                    canvasState.connectingFromNodeId!, tappedNode.id);
              } else {
                notifier.selectNode(tappedNode.id);
              }
            } else {
              notifier.deselectAll();
            }
          },
          onDoubleTapDown: (details) {
            final pos = _toCanvasPosition(details.localPosition);
            final tappedNode = _findNodeAt(pos, canvasState.mindMap.nodes);

            if (tappedNode != null) {
              _showNodeEditor(context, notifier, tappedNode);
            } else {
              notifier.addNode(x: pos.dx, y: pos.dy);
            }
          },
          onLongPressStart: (details) {
            final pos = _toCanvasPosition(details.localPosition);
            final tappedNode = _findNodeAt(pos, canvasState.mindMap.nodes);
            if (tappedNode != null) {
              notifier.startConnecting(tappedNode.id);
            }
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: AppConstants.minScale,
            maxScale: AppConstants.maxScale,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: SizedBox(
              width: AppConstants.canvasSize,
              height: AppConstants.canvasSize,
              child: Stack(
                children: [
                  // Canvas background
                  Container(color: const Color(0xFFFAFAFA)),
                  // Grid pattern
                  CustomPaint(
                    size: const Size(AppConstants.canvasSize, AppConstants.canvasSize),
                    painter: _GridPainter(),
                  ),
                  // Edges and nodes
                  CustomPaint(
                    size: const Size(AppConstants.canvasSize, AppConstants.canvasSize),
                    painter: CanvasPainter(
                      mindMap: canvasState.mindMap,
                      selectedNodeId: canvasState.selectedNodeId,
                      connectingFromNodeId: canvasState.connectingFromNodeId,
                    ),
                  ),
                  // Draggable node overlays
                  ...canvasState.mindMap.nodes.map((node) {
                    return Positioned(
                      left: node.x + AppConstants.canvasSize / 2 -
                          AppConstants.nodeWidth / 2,
                      top: node.y + AppConstants.canvasSize / 2 -
                          AppConstants.nodeHeight / 2,
                      width: AppConstants.nodeWidth,
                      height: AppConstants.nodeHeight,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          notifier.moveNode(node.id, details.delta.dx,
                              details.delta.dy);
                        },
                        child: const SizedBox.expand(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: ToolbarWidget(
        mindMap: widget.mindMap,
        selectedNodeId: canvasState.selectedNodeId,
        onAddNode: () => notifier.addNode(
          x: 0,
          y: 0,
          parentId: canvasState.selectedNodeId,
        ),
        onDeleteNode: canvasState.selectedNodeId != null
            ? () => notifier.deleteNode(canvasState.selectedNodeId!)
            : null,
        onExport: () {},
      ),
    );
  }

  Offset _toCanvasPosition(Offset localPosition) {
    final matrix = _transformController.value;
    final inverse = Matrix4.inverted(matrix);
    final v = Vector3(localPosition.dx, localPosition.dy, 0);
    final transformed = inverse.transformed3(v);
    return Offset(
      transformed.x - AppConstants.canvasSize / 2,
      transformed.y - AppConstants.canvasSize / 2,
    );
  }

  MindNode? _findNodeAt(Offset pos, List<MindNode> nodes) {
    const hw = AppConstants.nodeWidth / 2;
    const hh = AppConstants.nodeHeight / 2;
    for (final node in nodes.reversed) {
      if (pos.dx >= node.x - hw &&
          pos.dx <= node.x + hw &&
          pos.dy >= node.y - hh &&
          pos.dy <= node.y + hh) {
        return node;
      }
    }
    return null;
  }

  void _showNodeEditor(
      BuildContext context, CanvasNotifier notifier, MindNode node) {
    showDialog(
      context: context,
      builder: (_) => NodeEditorDialog(
        node: node,
        onSave: (text, style) {
          notifier.updateNodeText(node.id, text);
          notifier.updateNodeStyle(node.id, style);
        },
        onDelete: () => notifier.deleteNode(node.id),
      ),
    );
  }
}

// Simple grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(40)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

