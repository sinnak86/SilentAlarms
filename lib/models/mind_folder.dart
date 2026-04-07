class MindFolder {
  final String id;
  final String name;
  final String? parentId; // null = root level
  final DateTime createdAt;

  const MindFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  MindFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
  }) {
    return MindFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MindFolder.fromJson(Map<String, dynamic> json) => MindFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
