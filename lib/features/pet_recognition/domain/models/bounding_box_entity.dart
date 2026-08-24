/// Representa a caixa delimitadora (bounding box) de um animal detectado pelo YOLOv8n.
class BoundingBoxEntity {
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;
  final double confidence;
  final String label; // 'dog', 'cat', etc.

  const BoundingBoxEntity({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.confidence,
    required this.label,
  });

  /// Largura normalizada da caixa delimitadora (0.0 a 1.0)
  double get width => (xMax - xMin).clamp(0.0, 1.0);

  /// Altura normalizada da caixa delimitadora (0.0 a 1.0)
  double get height => (yMax - yMin).clamp(0.0, 1.0);

  /// Área normalizada ocupada pela caixa
  double get area => width * height;

  factory BoundingBoxEntity.fromJson(Map<String, dynamic> json) {
    return BoundingBoxEntity(
      xMin: (json['x_min'] as num?)?.toDouble() ?? 0.0,
      yMin: (json['y_min'] as num?)?.toDouble() ?? 0.0,
      xMax: (json['x_max'] as num?)?.toDouble() ?? 1.0,
      yMax: (json['y_max'] as num?)?.toDouble() ?? 1.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] as String? ?? 'pet',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x_min': xMin,
      'y_min': yMin,
      'x_max': xMax,
      'y_max': yMax,
      'confidence': confidence,
      'label': label,
    };
  }

  BoundingBoxEntity copyWith({
    double? xMin,
    double? yMin,
    double? xMax,
    double? yMax,
    double? confidence,
    String? label,
  }) {
    return BoundingBoxEntity(
      xMin: xMin ?? this.xMin,
      yMin: yMin ?? this.yMin,
      xMax: xMax ?? this.xMax,
      yMax: yMax ?? this.yMax,
      confidence: confidence ?? this.confidence,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundingBoxEntity &&
          runtimeType == other.runtimeType &&
          xMin == other.xMin &&
          yMin == other.yMin &&
          xMax == other.xMax &&
          yMax == other.yMax &&
          confidence == other.confidence &&
          label == other.label;

  @override
  int get hashCode => Object.hash(xMin, yMin, xMax, yMax, confidence, label);
}
