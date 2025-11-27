import 'bounding_box.dart';

/// Face detection/embedding result containing location and confidence data
class Face {
  final int? faceIndex;
  final BoundingBox? bbox;
  final double? confidence;
  final int? embeddingDimension;
  final int? pointId;
  final Map<String, dynamic>? landmarks;

  Face({
    this.faceIndex,
    this.bbox,
    this.confidence,
    this.embeddingDimension,
    this.pointId,
    this.landmarks,
  });

  /// Create Face from JSON response
  factory Face.fromJson(Map<String, dynamic> json) {
    return Face(
      faceIndex: json['face_index'] as int?,
      bbox: json['bbox'] != null
          ? BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      embeddingDimension: json['embedding_dimension'] as int?,
      pointId: json['point_id'] as int?,
      landmarks: json['landmarks'] as Map<String, dynamic>?,
    );
  }

  /// Convert Face to JSON
  Map<String, dynamic> toJson() {
    return {
      'face_index': faceIndex,
      if (bbox != null) 'bbox': bbox!.toJson(),
      'confidence': confidence,
      'embedding_dimension': embeddingDimension,
      'point_id': pointId,
      'landmarks': landmarks,
    };
  }

  @override
  String toString() =>
      'Face(faceIndex: $faceIndex, confidence: $confidence, embeddingDimension: $embeddingDimension)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Face &&
          runtimeType == other.runtimeType &&
          faceIndex == other.faceIndex &&
          bbox == other.bbox &&
          confidence == other.confidence &&
          embeddingDimension == other.embeddingDimension &&
          pointId == other.pointId &&
          landmarks == other.landmarks;

  @override
  int get hashCode =>
      faceIndex.hashCode ^
      bbox.hashCode ^
      confidence.hashCode ^
      embeddingDimension.hashCode ^
      pointId.hashCode ^
      landmarks.hashCode;
}
