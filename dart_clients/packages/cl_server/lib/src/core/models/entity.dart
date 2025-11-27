/// Entity model representing a media store item
/// Corresponds to the Item schema from the media_store service
class Entity {
  final int id;
  final bool isCollection;
  final String label;
  final String? description;
  final int? parentId;
  final DateTime? addedDate;
  final DateTime? updatedDate;
  final DateTime? createDate;
  final int? addedBy;
  final int? updatedBy;
  final int? fileSize;
  final int? height;
  final int? width;
  final int? duration;
  final String? mimeType;
  final String? type;
  final String? extension;
  final String? md5;
  final String? filePath;
  final bool? isDeleted;

  Entity({
    required this.id,
    required this.isCollection,
    required this.label,
    this.description,
    this.parentId,
    this.addedDate,
    this.updatedDate,
    this.createDate,
    this.addedBy,
    this.updatedBy,
    this.fileSize,
    this.height,
    this.width,
    this.duration,
    this.mimeType,
    this.type,
    this.extension,
    this.md5,
    this.filePath,
    this.isDeleted,
  });

  /// Create Entity from JSON response
  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] as int,
      isCollection: json['is_collection'] as bool,
      label: json['label'] as String,
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      addedDate: json['added_date'] != null
          ? _parseDate(json['added_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? _parseDate(json['updated_date'])
          : null,
      createDate: json['create_date'] != null
          ? _parseDate(json['create_date'])
          : null,
      addedBy: _parseNullableInt(json['added_by']),
      updatedBy: _parseNullableInt(json['updated_by']),
      fileSize: _parseNullableInt(json['file_size']),
      height: _parseNullableInt(json['height']),
      width: _parseNullableInt(json['width']),
      duration: _parseNullableInt(json['duration']),
      mimeType: json['mime_type'] as String?,
      type: json['type'] as String?,
      extension: json['extension'] as String?,
      md5: json['md5'] as String?,
      filePath: json['file_path'] as String?,
      isDeleted: json['is_deleted'] as bool?,
    );
  }

  /// Convert Entity to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_collection': isCollection,
      'label': label,
      'description': description,
      'parent_id': parentId,
      'added_date': addedDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'create_date': createDate?.toIso8601String(),
      'added_by': addedBy,
      'updated_by': updatedBy,
      'file_size': fileSize,
      'height': height,
      'width': width,
      'duration': duration,
      'mime_type': mimeType,
      'type': type,
      'extension': extension,
      'md5': md5,
      'file_path': filePath,
      'is_deleted': isDeleted,
    };
  }

  /// Parse nullable integer safely
  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parse date from either string (ISO8601) or integer (milliseconds since epoch)
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.parse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  @override
  String toString() {
    return 'Entity(id: $id, label: $label, isCollection: $isCollection, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isCollection == other.isCollection &&
          label == other.label &&
          description == other.description &&
          parentId == other.parentId &&
          addedDate == other.addedDate &&
          updatedDate == other.updatedDate &&
          createDate == other.createDate &&
          addedBy == other.addedBy &&
          updatedBy == other.updatedBy &&
          fileSize == other.fileSize &&
          height == other.height &&
          width == other.width &&
          duration == other.duration &&
          mimeType == other.mimeType &&
          type == other.type &&
          extension == other.extension &&
          md5 == other.md5 &&
          filePath == other.filePath &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode =>
      id.hashCode ^
      isCollection.hashCode ^
      label.hashCode ^
      description.hashCode ^
      parentId.hashCode ^
      addedDate.hashCode ^
      updatedDate.hashCode ^
      createDate.hashCode ^
      addedBy.hashCode ^
      updatedBy.hashCode ^
      fileSize.hashCode ^
      height.hashCode ^
      width.hashCode ^
      duration.hashCode ^
      mimeType.hashCode ^
      type.hashCode ^
      extension.hashCode ^
      md5.hashCode ^
      filePath.hashCode ^
      isDeleted.hashCode;
}
