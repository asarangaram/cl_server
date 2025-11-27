/// Result from image embedding task (CLIP model)
class ImageEmbeddingResult {
  final int? embeddingDimension;
  final bool? storedInVectorDb;
  final String? collection;
  final int? pointId;

  ImageEmbeddingResult({
    this.embeddingDimension,
    this.storedInVectorDb,
    this.collection,
    this.pointId,
  });

  /// Create ImageEmbeddingResult from JSON response
  factory ImageEmbeddingResult.fromJson(Map<String, dynamic> json) {
    return ImageEmbeddingResult(
      embeddingDimension: json['embedding_dimension'] as int?,
      storedInVectorDb: json['stored_in_vector_db'] as bool?,
      collection: json['collection'] as String?,
      pointId: json['point_id'] as int?,
    );
  }

  /// Convert ImageEmbeddingResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'embedding_dimension': embeddingDimension,
      'stored_in_vector_db': storedInVectorDb,
      'collection': collection,
      'point_id': pointId,
    };
  }

  @override
  String toString() =>
      'ImageEmbeddingResult(embeddingDimension: $embeddingDimension, collection: $collection, pointId: $pointId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageEmbeddingResult &&
          runtimeType == other.runtimeType &&
          embeddingDimension == other.embeddingDimension &&
          storedInVectorDb == other.storedInVectorDb &&
          collection == other.collection &&
          pointId == other.pointId;

  @override
  int get hashCode =>
      embeddingDimension.hashCode ^
      storedInVectorDb.hashCode ^
      collection.hashCode ^
      pointId.hashCode;
}
