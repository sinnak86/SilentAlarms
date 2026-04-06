import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/mind_map.dart';
import '../../models/mind_node.dart';
import '../../models/node_style.dart';
import '../../shared/constants.dart';

class CanvasPainter extends CustomPainter {
  final MindMap mindMap;
  final String? selectedNodeId;
  final String? connectingFromNodeId;

  CanvasPainter({
    required this.mindMap,
    this.selectedNodeId,
    this.connectingFromNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawEdges(Canvas canvas) {
    final nodeMap = {for (final n in mindMap.nodes) n.id: n};

    for (final edge in mindMap.edges) {
      final from = nodeMap[edge.fromNodeId];
      final to = nodeMap[edge.toNodeId];
      if (from == null || to == null) continue;

      final paint = Paint()
        ..color = edge.style.color
        ..strokeWidth = edge.style.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final fromCenter = Offset(from.x, from.y);
      final toCenter = Offset(to.x, to.y);

      final path = _buildBezierPath(fromCenter, toCenter);
      canvas.drawPath(path, paint);

      if (edge.style.hasArrow) {
        _drawArrow(canvas, fromCenter, toCenter, paint);
      }
    }
  }

  Path _buildBezierPath(Offset from, Offset to) {
    final path = Path();
    path.moveTo(from.dx, from.dy);
    final controlX = (from.dx + to.dx) / 2;
    path.cubicTo(
      controlX, from.dy,
      controlX, to.dy,
      to.dx, to.dy,
    );
    return path;
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 10.0;
    final angle = atan2(to.dy - from.dy, to.dx - from.dx);
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * cos(angle - pi / 6),
      to.dy - arrowSize * sin(angle - pi / 6),
    );
    path.lineTo(
      to.dx - arrowSize * cos(angle + pi / 6),
      to.dy - arrowSize * sin(angle + pi / 6),
    );
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  void _drawNodes(Canvas canvas) {
    for (final node in mindMap.nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawNode(Canvas canvas, MindNode node) {
    final isSelected = node.id == selectedNodeId;
    final isConnecting = node.id == connectingFromNodeId;

    final w = AppConstants.nodeWidth;
    final h = AppConstants.nodeHeight;
    final rect = Rect.fromCenter(
      center: Offset(node.x, node.y),
      width: w,
      height: h,
    );

    // Shadow
    if (isSelected) {
      final shadowPaint = Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.translate(0, 2), const Radius.circular(10)),
        shadowPaint,
      );
    }

    // Fill
    final fillPaint = Paint()
      ..color = isConnecting
          ? node.style.color.withAlpha(180)
          : node.style.color
      ..style = PaintingStyle.fill;

    _drawShape(canvas, rect, node.style.shape, fillPaint);

    // Selection border
    if (isSelected) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      _drawShape(canvas, rect, node.style.shape, borderPaint);
    }

    // Text
    final textSpan = TextSpan(
      text: node.text,
      style: TextStyle(
        color: node.style.textColor,
        fontSize: node.style.fontSize,
        fontWeight: node.isRoot ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: w - 12);
    textPainter.paint(
      canvas,
      Offset(
        node.x - textPainter.width / 2,
        node.y - textPainter.height / 2,
      ),
    );
  }

  void _drawShape(Canvas canvas, Rect rect, NodeShape shape, Paint paint) {
    switch (shape) {
      case NodeShape.rectangle:
        canvas.drawRect(rect, paint);
      case NodeShape.roundedRectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          paint,
        );
      case NodeShape.ellipse:
        canvas.drawOval(rect, paint);
      case NodeShape.diamond:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return oldDelegate.mindMap != mindMap ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.connectingFromNodeId != connectingFromNodeId;
  }
}
