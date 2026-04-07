import 'mind_node.dart';
import 'mind_edge.dart';

class MindMap {
  final String id;
  final String title;
  final List<MindNode> nodes;
  final List<MindEdge> edges;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final List<double>? viewTransform; // Matrix4 storage (16 values)
  final String? folderId;

  MindMap({
    required this.id,
    required this.title,
    List<MindNode>? nodes,
    List<MindEdge>? edges,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.viewTransform,
    this.folderId,
  })  : nodes = nodes ?? [],
        edges = edges ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  MindMap copyWith({
    String? id,
    String? title,
    List<MindNode>? nodes,
    List<MindEdge>? edges,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    List<double>? viewTransform,
    String? folderId,
  }) {
    return MindMap(
      id: id ?? this.id,
      title: title ?? this.title,
      nodes: nodes ?? List.from(this.nodes),
      edges: edges ?? List.from(this.edges),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId ?? this.userId,
      viewTransform: viewTransform ?? this.viewTransform,
      folderId: folderId ?? this.folderId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'userId': userId,
        'viewTransform': viewTransform,
        'folderId': folderId,
      };

  factory MindMap.fromJson(Map<String, dynamic> json) => MindMap(
        id: json['id'] as String,
        title: json['title'] as String,
        nodes: (json['nodes'] as List<dynamic>)
            .map((n) => MindNode.fromJson(n as Map<String, dynamic>))
            .toList(),
        edges: (json['edges'] as List<dynamic>)
            .map((e) => MindEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        userId: json['userId'] as String?,
        viewTransform: (json['viewTransform'] as List<dynamic>?)
            ?.map((v) => (v as num).toDouble())
            .toList(),
        folderId: json['folderId'] as String?,
      );
}
