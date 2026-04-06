import 'node_style.dart';

class MindNode {
  final String id;
  final String text;
  final double x;
  final double y;
  final NodeStyle style;
  final String? parentId;
  final bool isRoot;

  const MindNode({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    NodeStyle? style,
    this.parentId,
    this.isRoot = false,
  }) : style = style ?? const NodeStyle();

  MindNode copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    NodeStyle? style,
    String? parentId,
    bool clearParent = false,
    bool? isRoot,
  }) {
    return MindNode(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      style: style ?? this.style,
      parentId: clearParent ? null : parentId ?? this.parentId,
      isRoot: isRoot ?? this.isRoot,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'style': style.toJson(),
        'parentId': parentId,
        'isRoot': isRoot,
      };

  factory MindNode.fromJson(Map<String, dynamic> json) => MindNode(
        id: json['id'] as String,
        text: json['text'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        style: NodeStyle.fromJson(json['style'] as Map<String, dynamic>),
        parentId: json['parentId'] as String?,
        isRoot: json['isRoot'] as bool? ?? false,
      );
}
