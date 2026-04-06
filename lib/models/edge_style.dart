import 'dart:ui';

enum EdgeLineStyle { solid, dashed }

class EdgeStyle {
  final int colorValue;
  final double strokeWidth;
  final bool hasArrow;
  final int lineStyleIndex;

  const EdgeStyle({
    this.colorValue = 0xFF9E9E9E,
    this.strokeWidth = 2.0,
    this.hasArrow = false,
    this.lineStyleIndex = 0,
  });

  Color get color => Color(colorValue);
  EdgeLineStyle get lineStyle => EdgeLineStyle.values[lineStyleIndex];

  EdgeStyle copyWith({
    int? colorValue,
    double? strokeWidth,
    bool? hasArrow,
    int? lineStyleIndex,
  }) {
    return EdgeStyle(
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      hasArrow: hasArrow ?? this.hasArrow,
      lineStyleIndex: lineStyleIndex ?? this.lineStyleIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'hasArrow': hasArrow,
        'lineStyleIndex': lineStyleIndex,
      };

  factory EdgeStyle.fromJson(Map<String, dynamic> json) => EdgeStyle(
        colorValue: json['colorValue'] as int,
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        hasArrow: json['hasArrow'] as bool,
        lineStyleIndex: json['lineStyleIndex'] as int,
      );
}
