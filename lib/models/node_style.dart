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
        0xFF007AFF, // iOS Blue
        0xFF34C759, // iOS Green
        0xFFFF9500, // iOS Orange
        0xFFFF2D55, // iOS Pink
        0xFF5856D6, // iOS Purple
        0xFF5AC8FA, // iOS Teal
        0xFFFF3B30, // iOS Red
        0xFFAF52DE, // iOS Violet
      ];
}
