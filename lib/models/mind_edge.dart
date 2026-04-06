import 'edge_style.dart';

class MindEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final EdgeStyle style;

  const MindEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    EdgeStyle? style,
  }) : style = style ?? const EdgeStyle();

  MindEdge copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    EdgeStyle? style,
  }) {
    return MindEdge(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      style: style ?? this.style,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'style': style.toJson(),
      };

  factory MindEdge.fromJson(Map<String, dynamic> json) => MindEdge(
        id: json['id'] as String,
        fromNodeId: json['fromNodeId'] as String,
        toNodeId: json['toNodeId'] as String,
        style: EdgeStyle.fromJson(json['style'] as Map<String, dynamic>),
      );
}
