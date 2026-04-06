import 'dart:ui';

enum NodeShape { rectangle, roundedRectangle, ellipse, diamond }

class NodeStyle {
  final int colorValue;
  final int shapeIndex;
  final double fontSize;
  final int textColorValue;

  const NodeStyle({
    this.colorValue = 0xFF4CAF50,
    this.shapeIndex = 1,
    this.fontSize = 14.0,
    this.textColorValue = 0xFFFFFFFF,
  });

  Color get color => Color(colorValue);
  Color get textColor => Color(textColorValue);
  NodeShape get shape => NodeShape.values[shapeIndex];

  NodeStyle copyWith({
    int? colorValue,
    int? shapeIndex,
    double? fontSize,
    int? textColorValue,
  }) {
    return NodeStyle(
      colorValue: colorValue ?? this.colorValue,
      shapeIndex: shapeIndex ?? this.shapeIndex,
      fontSize: fontSize ?? this.fontSize,
      textColorValue: textColorValue ?? this.textColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'colorValue': colorValue,
        'shapeIndex': shapeIndex,
        'fontSize': fontSize,
        'textColorValue': textColorValue,
      };

  factory NodeStyle.fromJson(Map<String, dynamic> json) => NodeStyle(
        colorValue: json['colorValue'] as int,
        shapeIndex: json['shapeIndex'] as int,
        fontSize: (json['fontSize'] as num).toDouble(),
        textColorValue: json['textColorValue'] as int,
      );

  static List<int> get presetColors => [
        0xFF4CAF50,
        0xFF2196F3,
        0xFFFF9800,
        0xFFE91E63,
        0xFF9C27B0,
        0xFF00BCD4,
        0xFFF44336,
        0xFF607D8B,
      ];
}
