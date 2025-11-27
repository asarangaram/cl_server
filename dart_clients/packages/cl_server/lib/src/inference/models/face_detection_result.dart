import 'face.dart';

/// Result from face detection task (RetinaFace model)
class FaceDetectionResult {
  final List<Face>? faces;
  final int? faceCount;

  FaceDetectionResult({
    this.faces,
    this.faceCount,
  });

  /// Create FaceDetectionResult from JSON response
  factory FaceDetectionResult.fromJson(Map<String, dynamic> json) {
    return FaceDetectionResult(
      faces: (json['faces'] as List<dynamic>?)
          ?.map((e) => Face.fromJson(e as Map<String, dynamic>))
          .toList(),
      faceCount: json['face_count'] as int?,
    );
  }

  /// Convert FaceDetectionResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'faces': faces?.map((e) => e.toJson()).toList(),
      'face_count': faceCount,
    };
  }

  @override
  String toString() => 'FaceDetectionResult(faceCount: $faceCount, faces: ${faces?.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceDetectionResult &&
          runtimeType == other.runtimeType &&
          faces == other.faces &&
          faceCount == other.faceCount;

  @override
  int get hashCode => faces.hashCode ^ faceCount.hashCode;
}
