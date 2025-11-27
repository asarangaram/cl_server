/// Pagination metadata for list responses
class PaginationMetadata {
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  PaginationMetadata({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  /// Create PaginationMetadata from JSON response
  factory PaginationMetadata.fromJson(Map<String, dynamic> json) {
    return PaginationMetadata(
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalItems: json['total_items'] as int,
      totalPages: json['total_pages'] as int,
      hasNext: json['has_next'] as bool,
      hasPrev: json['has_prev'] as bool,
    );
  }

  /// Convert PaginationMetadata to JSON
  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'page_size': pageSize,
      'total_items': totalItems,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
    };
  }

  @override
  String toString() {
    return 'PaginationMetadata(page: $page, pageSize: $pageSize, totalItems: $totalItems, totalPages: $totalPages)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationMetadata &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          pageSize == other.pageSize &&
          totalItems == other.totalItems &&
          totalPages == other.totalPages &&
          hasNext == other.hasNext &&
          hasPrev == other.hasPrev;

  @override
  int get hashCode =>
      page.hashCode ^
      pageSize.hashCode ^
      totalItems.hashCode ^
      totalPages.hashCode ^
      hasNext.hashCode ^
      hasPrev.hashCode;
}
