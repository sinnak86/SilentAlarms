import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;
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

  String? _dragNodeId;
  Timer? _saveTransformTimer;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOrCenterView());
  }

  void _onTransformChanged() {
    setState(() {});
    // Debounce: save transform 800ms after last change
    _saveTransformTimer?.cancel();
    _saveTransformTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final matrix = _transformController.value.storage.toList();
      ref.read(canvasProvider(widget.mindMap).notifier).saveViewTransform(matrix);
    });
  }

  void _restoreOrCenterView() {
    if (!mounted) return;
    final saved = widget.mindMap.viewTransform;
    if (saved != null && saved.length == 16) {
      _transformController.value = Matrix4.fromList(saved);
    } else {
      _centerView();
    }
  }

  void _centerView() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final nodes = widget.mindMap.nodes;
    final rootNode = nodes.isNotEmpty
        ? nodes.firstWhere((n) => n.isRoot, orElse: () => nodes.first)
        : null;
    final tx = rootNode != null
        ? size.width / 2 - rootNode.x
        : size.width / 2;
    final ty = rootNode != null
        ? size.height / 2 - rootNode.y
        : size.height / 2;
    _transformController.value = Matrix4.identity()..translate(tx, ty);
  }

  @override
  void dispose() {
    _saveTransformTimer?.cancel();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider(widget.mindMap));
    final notifier = ref.read(canvasProvider(widget.mindMap).notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.75),
              foregroundColor: const Color(0xFF1C1C1E),
              elevation: 0,
              title: Text(canvasState.mindMap.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: 'Center view',
                  onPressed: _centerView,
                ),
                if (canvasState.isDirty)
                  IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Save',
                    onPressed: () => notifier.save(),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2F2F7), Color(0xFFE8EFF9)],
          ),
        ),
        child: RepaintBoundary(
          key: _repaintKey,
          child: Stack(
            children: [
              // ── Infinite grid (fills the whole screen, follows pan/zoom) ──
              CustomPaint(
                painter: _InfiniteGridPainter(_transformController.value),
                child: const SizedBox.expand(),
              ),
              // ── Pan/zoom canvas with nodes & edges ──
              GestureDetector(
                onTapUp: (details) {
                  final pos = _toCanvasPosition(details.localPosition);
                  final tappedNode =
                      _findNodeAt(pos, canvasState.mindMap.nodes);
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
                  final tappedNode =
                      _findNodeAt(pos, canvasState.mindMap.nodes);
                  if (tappedNode != null) {
                    _showNodeEditor(context, notifier, tappedNode);
                  } else {
                    notifier.addNode(x: pos.dx, y: pos.dy);
                  }
                },
                onLongPressStart: (details) {
                  final pos = _toCanvasPosition(details.localPosition);
                  final tappedNode =
                      _findNodeAt(pos, canvasState.mindMap.nodes);
                  if (tappedNode != null) {
                    notifier.startConnecting(tappedNode.id);
                  }
                },
                child: Listener(
                  onPointerDown: (event) {
                    final pos = _toCanvasPosition(event.localPosition);
                    final node = _findNodeAt(pos, canvasState.mindMap.nodes);
                    if (node != null) {
                      setState(() => _dragNodeId = node.id);
                    }
                  },
                  onPointerMove: (event) {
                    if (_dragNodeId != null) {
                      final scale =
                          _transformController.value.getMaxScaleOnAxis();
                      final scaledDx = event.delta.dx / scale;
                      final scaledDy = event.delta.dy / scale;
                      notifier.moveNode(_dragNodeId!, scaledDx, scaledDy);
                    }
                  },
                  onPointerUp: (_) => setState(() => _dragNodeId = null),
                  onPointerCancel: (_) => setState(() => _dragNodeId = null),
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: AppConstants.minScale,
                    maxScale: AppConstants.maxScale,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    panEnabled: _dragNodeId == null,
                    child: SizedBox(
                      width: AppConstants.canvasSize,
                      height: AppConstants.canvasSize,
                      child: CustomPaint(
                        size: const Size(
                            AppConstants.canvasSize, AppConstants.canvasSize),
                        painter: CanvasPainter(
                          mindMap: canvasState.mindMap,
                          selectedNodeId: canvasState.selectedNodeId,
                          connectingFromNodeId:
                              canvasState.connectingFromNodeId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ToolbarWidget(
        mindMap: widget.mindMap,
        selectedNodeId: canvasState.selectedNodeId,
        onAddNodeLeft: () => notifier.addNode(
          parentId: canvasState.selectedNodeId,
          direction: 'left',
        ),
        onAddNodeRight: () => notifier.addNode(
          parentId: canvasState.selectedNodeId,
          direction: 'right',
        ),
        onDeleteNode: canvasState.selectedNodeId != null
            ? () => notifier.deleteNode(canvasState.selectedNodeId!)
            : null,
        onRenameNode: canvasState.selectedNodeId != null
            ? () {
                final node = canvasState.mindMap.nodes.firstWhere(
                    (n) => n.id == canvasState.selectedNodeId);
                _showRenameDialog(context, notifier, node.id, node.text);
              }
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
    return Offset(transformed.x, transformed.y);
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

  void _showRenameDialog(BuildContext context, CanvasNotifier notifier,
      String nodeId, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.abc, color: Color(0xFF007AFF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '노드명 입력',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          notifier.updateNodeText(nodeId, v.trim());
                        }
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Color(0xFF007AFF)),
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        notifier.updateNodeText(nodeId, ctrl.text.trim());
                      }
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

/// Infinite grid that fills the entire screen and follows pan/zoom.
class _InfiniteGridPainter extends CustomPainter {
  final Matrix4 transform;

  const _InfiniteGridPainter(this.transform);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withAlpha(25)
      ..strokeWidth = 1;

    // Extract scale and translation from the transform matrix
    final scale = transform.getMaxScaleOnAxis();
    final tx = transform.getTranslation().x;
    final ty = transform.getTranslation().y;

    const step = 40.0; // Grid cell size in canvas units
    final scaledStep = step * scale;

    // Offset so grid lines follow the canvas origin
    final offsetX = tx % scaledStep;
    final offsetY = ty % scaledStep;

    // Vertical lines
    for (double x = offsetX - scaledStep; x <= size.width + scaledStep;
        x += scaledStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = offsetY - scaledStep; y <= size.height + scaledStep;
        y += scaledStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_InfiniteGridPainter old) =>
      old.transform != transform;
}
