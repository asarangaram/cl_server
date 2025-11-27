import 'face.dart';

/// Result from face embedding task (face vector embeddings)
class FaceEmbeddingResult {
  final List<Face>? faces;
  final int? faceCount;
  final bool? storedInVectorDb;
  final String? collection;

  FaceEmbeddingResult({
    this.faces,
    this.faceCount,
    this.storedInVectorDb,
    this.collection,
  });

  /// Create FaceEmbeddingResult from JSON response
  factory FaceEmbeddingResult.fromJson(Map<String, dynamic> json) {
    return FaceEmbeddingResult(
      faces: (json['faces'] as List<dynamic>?)
          ?.map((e) => Face.fromJson(e as Map<String, dynamic>))
          .toList(),
      faceCount: json['face_count'] as int?,
      storedInVectorDb: json['stored_in_vector_db'] as bool?,
      collection: json['collection'] as String?,
    );
  }

  /// Convert FaceEmbeddingResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'faces': faces?.map((e) => e.toJson()).toList(),
      'face_count': faceCount,
      'stored_in_vector_db': storedInVectorDb,
      'collection': collection,
    };
  }

  @override
  String toString() =>
      'FaceEmbeddingResult(faceCount: $faceCount, collection: $collection, faces: ${faces?.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceEmbeddingResult &&
          runtimeType == other.runtimeType &&
          faces == other.faces &&
          faceCount == other.faceCount &&
          storedInVectorDb == other.storedInVectorDb &&
          collection == other.collection;

  @override
  int get hashCode =>
      faces.hashCode ^ faceCount.hashCode ^ storedInVectorDb.hashCode ^ collection.hashCode;
}
